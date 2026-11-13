// m3-minimize-plugin.cpp — Zero-dependency Hyprland plugin that translates
// Wayland/X11 client `set_minimized` requests (titlebar '-' button) into
// `movetoworkspacesilent special:minimized`.

#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <format>
#include <optional>
#include <string>
#include <vector>

static void log_msg(const std::string& msg) {
    if (FILE* f = std::fopen("/tmp/m3-minimize-plugin.log", "a")) {
        std::fprintf(f, "%s\n", msg.c_str());
        std::fclose(f);
    }
}

#define APICALL extern "C"
#define EXPORT  __attribute__((visibility("default")))
#define HANDLE  void*

struct PLUGIN_DESCRIPTION_INFO {
    std::string name;
    std::string description;
    std::string author;
    std::string version;
};

struct SFunctionMatch {
    void*       address = nullptr;
    std::string signature;
    std::string demangled;
};

struct SBackendStateRequest {
    std::optional<bool>    fullscreen;
    std::optional<int64_t> fullscreenMonitor;
    std::optional<bool>    maximized;
    std::optional<bool>    minimized;
};

class CFunctionHook {
  public:
    void* m_original = nullptr;
};

struct wl_array {
    size_t size;
    size_t alloc;
    void*  data;
};

// Exported by Hyprland / libwayland-server
extern "C" {
const char*                 __hyprland_api_get_hash();
std::vector<SFunctionMatch> findFunctionsByName(HANDLE handle, const std::string& name);
CFunctionHook*              createFunctionHook(HANDLE handle, const void* source, const void* destination);
bool                        removeFunctionHook(HANDLE handle, CFunctionHook* hook);
std::string                 invokeHyprctlCommand(const std::string& call, const std::string& args, const std::string& format);
void*                       wl_array_add(wl_array* array, size_t size);
}

APICALL EXPORT const char* __hyprland_api_get_client_hash() {
    return __hyprland_api_get_hash();
}

// CFunctionHook::hook() mangled symbol
extern "C" bool _ZN13CFunctionHook4hookEv(CFunctionHook* self);

static HANDLE         g_handle    = nullptr;
static CFunctionHook* g_hook      = nullptr;
static CFunctionHook* g_wmCapHook = nullptr;

using OrigOnUpdateStateFn = void (*)(void* thisptr, const SBackendStateRequest& req);
using OrigSendWmCapFn     = void (*)(void* thisptr, wl_array* caps);

static void hkSendWmCapabilities(void* thisptr, wl_array* caps) {
    if (caps) {
        bool      has_min = false;
        uint32_t* elems   = static_cast<uint32_t*>(caps->data);
        size_t    count   = caps->size / sizeof(uint32_t);
        for (size_t i = 0; i < count; ++i) {
            if (elems[i] == 4) { // XDG_TOPLEVEL_WM_CAPABILITIES_MINIMIZE
                has_min = true;
                break;
            }
        }
        if (!has_min) {
            if (uint32_t* p = static_cast<uint32_t*>(wl_array_add(caps, sizeof(uint32_t)))) {
                *p = 4;
                log_msg(std::format("hkSendWmCapabilities: added MINIMIZE (4) to toplevel {}", thisptr));
            }
        }
    }
    if (g_wmCapHook && g_wmCapHook->m_original) {
        ((OrigSendWmCapFn)g_wmCapHook->m_original)(thisptr, caps);
    }
}

static void hkOnUpdateState(void* thisptr, const SBackendStateRequest& req) {
    log_msg(std::format("hkOnUpdateState: this={} fs={} max={} min={} ({})",
                        thisptr,
                        req.fullscreen.has_value() ? (*req.fullscreen ? 1 : 0) : -1,
                        req.maximized.has_value() ? (*req.maximized ? 1 : 0) : -1,
                        req.minimized.has_value() ? 1 : 0,
                        req.minimized.has_value() ? (*req.minimized ? "true" : "false") : "none"));
    if (g_hook && g_hook->m_original) {
        ((OrigOnUpdateStateFn)g_hook->m_original)(thisptr, req);
    }

    if (req.minimized.has_value() && thisptr) {
        std::string addr = std::format("0x{:x}", reinterpret_cast<uintptr_t>(thisptr));
        if (*req.minimized) {
            std::string lua = std::format(
                "hl.dispatch(hl.dsp.window.move({{ workspace = 'special:minimized', follow = false, window = 'address:{}' }}))",
                addr);
            std::string res = invokeHyprctlCommand("eval", lua, "");
            log_msg(std::format("eval min res={}", res));
        } else {
            std::string lua = std::format(
                "hl.dispatch(hl.dsp.window.move({{ workspace = '+0', follow = true, window = 'address:{}' }}))",
                addr);
            std::string res = invokeHyprctlCommand("eval", lua, "");
            log_msg(std::format("eval unmin res={}", res));
        }
    }
}

APICALL EXPORT std::string pluginAPIVersion() {
    return "0.2";
}

APICALL EXPORT PLUGIN_DESCRIPTION_INFO pluginInit(HANDLE handle) {
    g_handle = handle;

    if (FILE* f = std::fopen("/tmp/m3-minimize-plugin.log", "w")) {
        std::fclose(f);
    }

    auto matches = findFunctionsByName(handle, "onUpdateState");
    log_msg(std::format("pluginInit: onUpdateState matches={}", matches.size()));
    for (const auto& m : matches) {
        log_msg(std::format("  match addr={} sig={} demangled={}", m.address, m.signature, m.demangled));
        if (m.demangled.find("CWindow::onUpdateState") != std::string::npos && m.address) {
            g_hook = createFunctionHook(handle, m.address, reinterpret_cast<const void*>(&hkOnUpdateState));
            log_msg(std::format("  createFunctionHook={}", (void*)g_hook));
            if (g_hook) {
                bool ok = _ZN13CFunctionHook4hookEv(g_hook);
                log_msg(std::format("  hook()={} orig={}", ok, g_hook->m_original));
            }
            break;
        }
    }

    auto capMatches = findFunctionsByName(handle, "sendWmCapabilities");
    log_msg(std::format("pluginInit: sendWmCapabilities matches={}", capMatches.size()));
    for (const auto& m : capMatches) {
        log_msg(std::format("  match addr={} sig={} demangled={}", m.address, m.signature, m.demangled));
        if (m.demangled.find("CXdgToplevel::sendWmCapabilities") != std::string::npos && m.address) {
            g_wmCapHook = createFunctionHook(handle, m.address, reinterpret_cast<const void*>(&hkSendWmCapabilities));
            log_msg(std::format("  createFunctionHook(wmCap)={}", (void*)g_wmCapHook));
            if (g_wmCapHook) {
                bool ok = _ZN13CFunctionHook4hookEv(g_wmCapHook);
                log_msg(std::format("  hook(wmCap)={} orig={}", ok, g_wmCapHook->m_original));
            }
            break;
        }
    }

    return {"m3-minimize", "Translate window minimize requests to special:minimized", "m3-hyprland", "1.0"};
}

APICALL EXPORT void pluginExit() {
    if (g_handle && g_hook) {
        removeFunctionHook(g_handle, g_hook);
        g_hook = nullptr;
    }
    if (g_handle && g_wmCapHook) {
        removeFunctionHook(g_handle, g_wmCapHook);
        g_wmCapHook = nullptr;
    }
}
