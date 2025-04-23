#include "include/helium_flutter/helium_flutter_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "helium_flutter_plugin.h"

void HeliumFlutterPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  helium_flutter::HeliumFlutterPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
