#include "Luau/Frontend.h"
#include "Luau/BuiltinDefinitions.h"

namespace luauAnalyze {
    struct SourceInfo {
        std::string code;
        bool is_module;
    };

    struct MemoryFileResolver : Luau::FileResolver {
        std::unordered_map<std::string, SourceInfo> sources;

        virtual std::optional<Luau::SourceCode> readSource(const Luau::ModuleName& name) {
            auto it = sources.find(name);
            if (it == sources.end()) {
                return std::nullopt;
            } else {
                auto source = std::move(sources[name]);
                sources.erase(it);

                auto type = source.is_module ? Luau::SourceCode::Type::Module : Luau::SourceCode::Type::Script;
                Luau::SourceCode info = { std::move(source.code), type };
                return std::move(info);
            }
        }

        void register_source(std::string name, std::string source, bool is_module) {
            sources[name] = { source, is_module };
        }
    };

    struct FrontendWrapper {
        std::unique_ptr<MemoryFileResolver> file_resolver;
        std::unique_ptr<Luau::NullConfigResolver> config_resolver;
        std::unique_ptr<Luau::Frontend> frontend;
    };
}

[[noreturn]] static void error(const char* error) {
    printf("internal error in crabsoup-mlua-analyze: %s\n", error);
    throw std::runtime_error("err");
}

extern "C" {
    struct RustCheckResultReceiver;
    struct RustString {
        const char* data;
        size_t len;
    };
    struct RustLineColumn {
        unsigned int line, column;
    };
    extern void luauAnalyze_push_result(
        RustCheckResultReceiver* receiver,
        RustString module,
        RustLineColumn error_start,
        RustLineColumn error_end,
        bool is_error,
        bool is_lint,
        RustString message
    );

    static RustString to_rust_string(std::string& str) {
        return { str.data(), str.length() };
    }
    static std::string from_rust_string(RustString str) {
        std::string new_str(str.data, str.len);
        return new_str;
    }
    static void push_to_receiver(RustCheckResultReceiver* receiver, Luau::TypeError& error) {
        auto message = toString(error);
        luauAnalyze_push_result(
            receiver,
            to_rust_string(error.moduleName),
            { error.location.begin.line, error.location.begin.column },
            { error.location.end.line, error.location.end.column },
            true,
            false,
            to_rust_string(message)
        );
    }
    static void push_to_receiver_lint(
        RustCheckResultReceiver* receiver,
        std::string& name,
        Luau::LintWarning& error,
        bool is_error
    ) {
        luauAnalyze_push_result(
            receiver,
            to_rust_string(name),
            { error.location.begin.line, error.location.begin.column },
            { error.location.end.line, error.location.end.column },
            is_error,
            true,
            to_rust_string(error.text)
        );
    }

    luauAnalyze::FrontendWrapper* luauAnalyze_new_frontend() {
        auto file_resolver = std::make_unique<luauAnalyze::MemoryFileResolver>();
        auto config_resolver = std::make_unique<Luau::NullConfigResolver>();

        Luau::FrontendOptions options;
        options.runLintChecks = true;
        options.moduleTimeLimitSec = 1.0;

        auto frontend = std::make_unique<Luau::Frontend>(&*file_resolver, &*config_resolver, options);
        Luau::registerBuiltinGlobals(*frontend.get(), frontend->globals);

        luauAnalyze::FrontendWrapper *wrapper = new luauAnalyze::FrontendWrapper();
        wrapper->file_resolver = std::move(file_resolver);
        wrapper->config_resolver = std::move(config_resolver);
        wrapper->frontend = std::move(frontend);
        return wrapper;
    }

    bool luauAnalyze_register_definitions(
        luauAnalyze::FrontendWrapper* wrapper,
        RustString r_module_name,
        RustString r_definitions
    ) {
        auto module_name = from_rust_string(r_module_name);
        auto definitions = from_rust_string(r_definitions);
        auto result = wrapper->frontend->loadDefinitionFile(
            wrapper->frontend->globals,
            wrapper->frontend->globals.globalScope,
            std::move(definitions),
            std::move(module_name),
            false
        );
        return result.success;
    }

    static std::vector<std::string> split_str(std::string s, std::string delimiter) {
        size_t pos_start = 0, pos_end, delim_len = delimiter.length();
        std::string token;
        std::vector<std::string> res;

        while ((pos_end = s.find(delimiter, pos_start)) != std::string::npos) {
            token = s.substr (pos_start, pos_end - pos_start);
            pos_start = pos_end + delim_len;
            res.push_back (token);
        }

        res.push_back (s.substr (pos_start));
        return res;
    }
    static bool add_deprecation_to_table(Luau::TableType* ttv, std::string& target, std::string& replacement) {
        if (ttv) {
            if (ttv->props.count(target)) {
                ttv->props[target].deprecated = true;
                if (replacement != "")
                    ttv->props[target].deprecatedSuggestion = replacement;
            }
            return true;
        } else {
            return false;
        }
    }
    void luauAnalyze_set_deprecation(
        luauAnalyze::FrontendWrapper* wrapper,
        RustString r_module_path,
        RustString r_replacement
    ) {
        auto module_path = from_rust_string(r_module_path);
        auto replacement = from_rust_string(r_replacement);
        bool has_replacement = replacement != "";

        auto split = split_str(module_path, ".");
        if (split.size() == 1) {
            auto astName = wrapper->frontend->globals.globalNames.names->getOrAdd(module_path.c_str());
            wrapper->frontend->globals.globalScope->bindings[astName].deprecated = true;
            if (has_replacement)
                wrapper->frontend->globals.globalScope->bindings[astName].deprecatedSuggestion = replacement;
        } else if (split.size() == 2) {
            auto binding = Luau::getGlobalBinding(wrapper->frontend->globals, split[0]);
            Luau::TableType* ttv = Luau::getMutable<Luau::TableType>(binding);
            if (ttv) {
                add_deprecation_to_table(ttv, module_path, replacement);
            } else {
                Luau::IntersectionType* intersection = Luau::getMutable<Luau::IntersectionType>(binding);
                if (intersection) {
                    for (auto& entry : intersection->parts) {
                        Luau::TableType* e_ttv = Luau::getMutable<Luau::TableType>(entry);
                        add_deprecation_to_table(e_ttv, module_path, replacement);
                    }
                } else {
                    error("Table not found?");
                }
            }
        } else {
            error("Invalid size (for now)");
        }
    }

    void luauAnalyze_freeze_definitions(luauAnalyze::FrontendWrapper* wrapper) {
        Luau::freeze(wrapper->frontend->globals.globalTypes);
        Luau::freeze(wrapper->frontend->globalsForAutocomplete.globalTypes);
    }

    void luauAnalyze_check(
        RustCheckResultReceiver* receiver,
        luauAnalyze::FrontendWrapper* wrapper,
        RustString r_name,
        RustString r_contents,
        bool is_module
    ) {
        auto name = from_rust_string(r_name);
        auto contents = from_rust_string(r_contents);

        wrapper->file_resolver->register_source(name, std::move(contents), is_module);
        auto result = wrapper->frontend->check(name);

        for (auto& entry : result.errors) push_to_receiver(receiver, entry);
        for (auto& entry : result.lintResult.errors) push_to_receiver_lint(receiver, name, entry, true);
        for (auto& entry : result.lintResult.warnings) push_to_receiver_lint(receiver, name, entry, false);

        wrapper->frontend->clear();
    }

    void luauAnalyze_free_frontend(luauAnalyze::FrontendWrapper* wrapper) {
        delete wrapper;
    }
}
