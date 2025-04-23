//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <helium_flutter/helium_flutter_plugin.h>

void fl_register_plugins(FlPluginRegistry* registry) {
  g_autoptr(FlPluginRegistrar) helium_flutter_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "HeliumFlutterPlugin");
  helium_flutter_plugin_register_with_registrar(helium_flutter_registrar);
}
