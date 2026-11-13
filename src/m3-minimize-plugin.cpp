// m3-minimize-plugin.cpp — Zero-dependency Hyprland plugin that translates
// Wayland/X11 client `set_minimized` requests (titlebar '-' button) into
// `movetoworkspacesilent special:minimized`.

#include <cstdint>
#include <cstdlib>
#include <format>
#include <optional>
#include <string>
#include <vector>

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

// Exported by Hyprland binary
extern "C" {
const char*                 __hyprland_api_get_hash();
std::vector<SFunctionMatch> findFunctionsByName(HANDLE handle, const std::string& name);
CFunctionHook*              createFunctionHook(HANDLE handle, const void* source, const void* destination);
bool                        removeFunctionHook(HANDLE handle, CFunctionHook* hook);
std::string                 invokeHyprctlCommand(const std::string& call, const std::string& args, const std::string& format);
}

APICALL EXPORT const char* __hyprland_api_get_client_hash() {
    return __hyprland_api_get_hash();
}

// CFunctionHook::hook() mangled symbol
extern "C" bool _ZN13CFunctionHook4hookEv(CFunctionHook* self);

static HANDLE         g_handle = nullptr;
static CFunctionHook* g_hook   = nullptr;

using OrigOnUpdateStateFn = void (*)(void* thisptr, const SBackendStateRequest& req);

static void hkOnUpdateState(void* thisptr, const SBackendStateRequest& req) {
    if (g_hook && g_hook->m_original) {
        ((OrigOnUpdateStateFn)g_hook->m_original)(thisptr, req);
    }

    if (req.minimized.has_value() && thisptr) {
        std::string addr = std::format("0x{:x}", reinterpret_cast<uintptr_t>(thisptr));
        if (*req.minimized) {
            std::string lua = std::format(
                "hl.dispatch(hl.dsp.window.move({{ workspace = 'special:minimized', follow = false, window = 'address:{}' }}))",
                addr);
            invokeHyprctlCommand("eval", lua, "");
        } else {
            std::string lua = std::format(
                "hl.dispatch(hl.dsp.window.move({{ workspace = '+0', follow = true, window = 'address:{}' }}))",
                addr);
            invokeHyprctlCommand("eval", lua, "");
        }
    }
}

APICALL EXPORT std::string pluginAPIVersion() {
    return "0.2";
}

APICALL EXPORT PLUGIN_DESCRIPTION_INFO pluginInit(HANDLE handle) {
    g_handle = handle;

    auto matches = findFunctionsByName(handle, "onUpdateState");
    for (const auto& m : matches) {
        if (m.demangled.find("CWindow::onUpdateState") != std::string::npos && m.address) {
            g_hook = createFunctionHook(handle, m.address, reinterpret_cast<const void*>(&hkOnUpdateState));
            if (g_hook) {
                _ZN13CFunctionHook4hookEv(g_hook);
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
}
