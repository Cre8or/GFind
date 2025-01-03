# General parameters
platform = "linuxbsd"
target = "template_release"
production = "yes"
optimize = "size"
lto = "full"
deprecated = "no"

# Modules
modules_enabled_by_default = "no"
module_regex_enabled = "yes"
module_glslang_enabled = "yes"
module_gdscript_enabled = "yes"
module_webp_enabled = "yes"
module_freetype_enabled = "yes"
module_gltf_enabled = "yes"
module_text_server_fb_enabled = "yes"

# Extra stuff
touch = "no"
libdecor = "no"
udev = "no"
speechd = "no"
pulseaudio = "no"
alsa = "no"
disable_3d = "yes"
#threads = "no" # Disabling threads causes issues with native file dialogs
openxr = "no"
graphite = "no"
