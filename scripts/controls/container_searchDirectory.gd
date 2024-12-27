# --------------------------------------------------------------------------------------------------
# Copyright 2024 Cre8or
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except
# in compliance with the License. You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software distributed under the License
# is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express
# or implied.
# See the License for the specific language governing permissions and limitations under the License.
# --------------------------------------------------------------------------------------------------

extends HBoxContainer
## Brief summary of this script/class.
##
## TODO: A description of this script. What does it handle? What is it intended for?[br]
## Newlines are also supported, so be verbose if possible.



@export var CtrlButton : Button
@export var CtrlText   : LineEdit
@export var CtrlDialog : FileDialog

@onready var _default_dir : String



# Built-in methods
# --------------------------------------------------------------------------------------------------
func _ready() -> void:
	CtrlButton.pressed.connect(_on_button_press)
	CtrlDialog.dir_selected.connect(_on_dir_selected)

	_default_dir = OS.get_environment("HOMEA")
	if not _default_dir:
		_default_dir = OS.get_executable_path().get_base_dir()

	CtrlText.set_placeholder(_default_dir)



# Public methods



# Private methods
# --------------------------------------------------------------------------------------------------
func _on_dir_selected(dir : String) -> void:
	CtrlText.set_text(dir)

# --------------------------------------------------------------------------------------------------
func _on_button_press() -> void:
	var dir := CtrlText.get_text()

	var DirAccessor := DirAccess.open(dir)

	if not DirAccessor:
		printerr("Directory \"" + dir + "\" does not exist!")
		dir = _default_dir

	print("Opening dialog at: \"" + dir + "\"")
	CtrlDialog.set_current_dir(dir)
	CtrlDialog.show()
