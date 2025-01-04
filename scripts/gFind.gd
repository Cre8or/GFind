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

extends Node
## Brief summary of this script/class.
##
## TODO: A description of this script. What does it handle? What is it intended for?[br]
## Newlines are also supported, so be verbose if possible.



# Classes
class T_Preview:
	var text  : String
	var left  : String
	var right : String

class T_Search_Settings:
	var search_recursively    : bool
	var search_case_sensitive : bool
	var use_regex             : bool
	var include_binary        : bool
	var include_hidden        : bool

class T_Search_Result:
	var file_name  : String
	var path       : String
	var path_short : String
	var matches    : int
	var size       : int
	var previews   : Array[T_Preview]



# Signals



# Enums
enum T_Status {
	IDLE,
	SEARCHING,
	DONE,
	ERROR_NO_DIRECTORY,
	ERROR_INVALID_DIRECTORY,
	ERROR_NO_SEARCH_TERM,
	ERROR_REGEX_SEARCH_TERM,
	ERROR_REGEX_REPLACE_TERM,
	ERROR_ITERATIONS
}



# Constants
const C_COLUMN_FILENAME   := 0
const C_COLUMN_MATCHES    := 1
const C_COLUMN_SIZE       := 2
const C_COLUMN_PATH_SHORT := 3

const C_MAX_SEARCH_ITERATIONS     := 1e5
const C_MAX_MATCH_PREVIEWS        := 10
const C_BINARY_TEST_BUFFER_LENGTH := 2048

const C_MAX_INTERVAL_BETWEEN_FRAMES := 20 # in ms
const C_TOOLTIP_SHOW_DELAY          := 500 # in ms
const C_MAX_PAD_LENGTH              := 10 # in characters 

const C_FILENAME_PREFERENCES := "preferences.ini"

const C_SECTION_PREVIOUS_SETTINGS := "Previous_Settings"
const C_SECTION_FILTERS           := "Filters"

const C_KEY_SEARCH_TERM           := "search_term"
const C_KEY_REPLACE_TERM          := "replace_term"
const C_KEY_SEARCH_RECURSIVELY    := "search_recursively"
const C_KEY_SEARCH_CASE_SENSITIVE := "search_case_sensitive"
const C_KEY_USE_REGEX             := "use_regex"
const C_KEY_INCLUDE_BINARY        := "include_binary"
const C_KEY_INCLUDE_HIDDEN        := "include_hidden"


# Exports
@export_category("GFind Controls")
@export var CtrlButtonBrowse         : Button
@export var CtrlSearchDir            : LineEdit
@export var CtrlSearchTerm           : TextEdit
@export var CtrlReplaceTerm          : TextEdit
@export var CtrlButtonSearch         : Button
@export var CtrlButtonReplace        : Button
@export var CtrlRecursive            : CheckBox
@export var CtrlCaseSensitive        : CheckBox
@export var CtrlRegex                : CheckBox
@export var CtrlIncludeBinary        : CheckBox
@export var CtrlIncludeHidden        : CheckBox
@export var CtrlStatus               : RichTextLabel
@export var CtrlTable                : Tree

@export var CtrlWindowConfirm        : Window
@export var CtrlButtonReplaceCancel  : Button
@export var CtrlButtonReplaceConfirm : Button

@export var CtrlWindowTooltip        : Window
@export var CtrlTooltip              : RichTextLabel

@export_category("Test settings (development only)")
@export var test_data_source_directory : String
@export var test_search_directory      : String
@export var test_search_term           : String
@export var test_replace_term          : String
@export var test_search_recursively    : bool
@export var test_search_case_sensitive : bool
@export var test_use_regex             : bool
@export var test_include_binary        : bool
@export var test_include_hidden        : bool



# Public properties



# Private properties
var _m_column_to_sort    := C_COLUMN_MATCHES
var _m_invert_sort_order := false
var _m_search_results    : Array[T_Search_Result]
var _m_regex             := RegEx.new()
var _m_iterations        := 0
var _m_executable_dir    : String



# Built-in methods
# --------------------------------------------------------------------------------------------------
func _ready() -> void:
	CtrlButtonSearch.pressed.connect(_on_search_pressed)
	CtrlButtonReplace.pressed.connect(_on_replace_pressed)
	CtrlTable.column_title_clicked.connect(_on_column_title_clicked)
	CtrlTable.item_activated.connect(_on_result_double_clicked)

	CtrlSearchDir.gui_input.connect(_on_gui_input.bindv([CtrlSearchDir]))
	CtrlSearchTerm.gui_input.connect(_on_gui_input.bindv([CtrlSearchTerm]))
	CtrlReplaceTerm.gui_input.connect(_on_gui_input.bindv([CtrlReplaceTerm]))

	CtrlWindowConfirm.close_requested.connect(_on_replace_cancel_pressed)
	CtrlButtonReplaceCancel.pressed.connect(_on_replace_cancel_pressed)
	CtrlButtonReplaceConfirm.pressed.connect(_on_replace_confirm_pressed)

	CtrlTable.set_column_title(C_COLUMN_FILENAME,   "File name")
	CtrlTable.set_column_title(C_COLUMN_MATCHES,    "Matches")
	CtrlTable.set_column_title(C_COLUMN_SIZE,       "Size")
	CtrlTable.set_column_title(C_COLUMN_PATH_SHORT, "Path")

	CtrlTable.set_column_expand_ratio(C_COLUMN_FILENAME,   20)
	CtrlTable.set_column_expand_ratio(C_COLUMN_MATCHES,    2)
	CtrlTable.set_column_expand_ratio(C_COLUMN_SIZE,       3)
	CtrlTable.set_column_expand_ratio(C_COLUMN_PATH_SHORT, 20)

	if OS.has_feature("editor"):
		_m_executable_dir = OS.get_user_data_dir()
	else:
		_m_executable_dir = OS.get_executable_path().get_base_dir()
	print("Executable directory: " + _m_executable_dir)

	_load_user_preferences()
	_parse_command_line()
	_set_status(T_Status.IDLE)

# --------------------------------------------------------------------------------------------------
func _notification(kind):
	if kind == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_user_preferences()

		get_tree().quit()



# Public methods



# Private methods
# --------------------------------------------------------------------------------------------------
func _on_search_pressed() -> void:

	if not _is_UI_input_valid():
		return

	_enable_search_ctrls(false)

	await _gfind_search(
		CtrlSearchDir.text,
		CtrlSearchTerm.text,
		_get_current_search_settings(),
		false
	)

	_enable_search_ctrls(true)

# --------------------------------------------------------------------------------------------------
func _on_replace_pressed() -> void:
	if not _is_UI_input_valid(true):
		return

	CtrlWindowConfirm.visible = true
	CtrlButtonReplaceCancel.grab_focus()

# --------------------------------------------------------------------------------------------------
func _on_replace_cancel_pressed() -> void:
	CtrlWindowConfirm.visible = false

# --------------------------------------------------------------------------------------------------
func _on_replace_confirm_pressed() -> void:
	CtrlWindowConfirm.visible = false
	await RenderingServer.frame_post_draw

	if not _is_UI_input_valid():
		return

	_enable_search_ctrls(false)

	await _gfind_search(
		CtrlSearchDir.text,
		CtrlSearchTerm.text,
		_get_current_search_settings(),
		true,
		CtrlReplaceTerm.text
	)

	_enable_search_ctrls(true)

# --------------------------------------------------------------------------------------------------
func _on_result_double_clicked() -> void:
	var entry := CtrlTable.get_selected()
	if not entry: return
	
	var path : String = entry.get_metadata(C_COLUMN_PATH_SHORT)
	if not path: return

	match OS.get_name().to_upper():
		"WINDOWS":
			# On Windows, CMD has a "call" command which handles file associations for us
			OS.execute("cmd.exe", ["/C", "call", path.replace("/", "\\")])
		"LINUX", "FREEBSD", "NETBSD", "OPENBSD", "BSD":
			# On Unix systems, xdg-open does the same (provided it exists - Wayland, anyone?)
			OS.execute("xdg-open", [path])
		_:
			# No clue how to do it on other systems, so skip for now
			return

# --------------------------------------------------------------------------------------------------
func _on_column_title_clicked(
	column              : int,
	_mouse_button_index : int
) -> void:
	if _mouse_button_index != 1: return # Ignore anything other than left clicks

	if _m_column_to_sort == column:
		_m_invert_sort_order = not _m_invert_sort_order
	else:
		_m_column_to_sort = column

	print("Column " + str(column) + " pressed")
	_sort_results()

# --------------------------------------------------------------------------------------------------
func _on_gui_input(
	event    : InputEvent,
	CtrlText : Control
) -> void:
	var event_key := event as InputEventKey
	if not CtrlText or not event_key: return

	# Only consider key press events
	if not event_key.pressed: return

	# Remap the tab key to focus on neighbouring controls
	match event_key.keycode:
		KEY_TAB:
			# Allow typing TAB when holding control
			# This is exclusive to TextEdit controls, as using tabs for e.g. the search directory
			# path seems unreasonable.
			if event_key.is_ctrl_pressed() and CtrlText is TextEdit:
				var tab := PackedByteArray([9]).get_string_from_ascii()

				CtrlText.accept_event()
				CtrlText.insert_text_at_caret(tab, 0)
				return

			# When not holding control, parse TAB presses as requests to switch focus to the next
			# or previous control
			var path := CtrlText.focus_next
			if event_key.shift_pressed:
				path = CtrlText.focus_previous

			if not path: return
			var CtrlNeighbour := CtrlText.get_node(path) as Control
	#
			if CtrlNeighbour:
				# Flag the event as being consumed
				# I don't know how it figures out which event is concerned, but somehow it works...
				CtrlText.accept_event()
				CtrlNeighbour.grab_focus()

		KEY_ENTER, KEY_KP_ENTER:
			# ENTER should trigger the button associated with this text field. Here we figure out
			# which one is relevant for the current control.
			var CtrlButton : Button
			match CtrlText:
				CtrlSearchDir:   CtrlButton = CtrlButtonBrowse
				CtrlSearchTerm:  CtrlButton = CtrlButtonSearch
				CtrlReplaceTerm: CtrlButton = CtrlButtonReplace

			if CtrlButton:
				CtrlText.accept_event()
				CtrlButton.pressed.emit()
	
# --------------------------------------------------------------------------------------------------
func _parse_command_line() -> void:

	# Default input focus onto the search directory field
	CtrlSearchDir.grab_focus()

	#region Test values (for development purposes)
	# Only run the code below if we're not running from within the editor.
	# Using Engine.is_editor_hint() does not work here, as that is intended for tool scripts.
	if OS.has_feature("editor"):
		# If a source directory is passed, the search directory is removed and a copy
		# of the source data is pasted in its place. This was useful during development
		# at times where the replace function would corrupt files.
		if test_data_source_directory and test_search_directory:
			if DirAccess.dir_exists_absolute(test_search_directory):
				OS.execute("rm", ["-r", test_search_directory])
			OS.execute("cp", ["-r", "-a", "-L", test_data_source_directory, test_search_directory])

		CtrlSearchDir.text               = test_search_directory
		CtrlSearchTerm.text              = test_search_term
		#CtrlSearchTerm.text             = "//[\\s]+([a-z0-9_\\- \\.!\\?'#,;:]+)"
		CtrlReplaceTerm.text             = test_replace_term
		CtrlRecursive.button_pressed     = test_search_recursively
		CtrlCaseSensitive.button_pressed = test_search_case_sensitive
		CtrlRegex.button_pressed         = test_use_regex
		CtrlIncludeBinary.button_pressed = test_include_binary
		CtrlIncludeHidden.button_pressed = test_include_hidden

		_on_search_pressed()
		return
	#endregion

	#region Proper command line parsing
	CtrlSearchDir.text = _m_executable_dir

	# Check if a working directory was passed (first argument after a blank "--")
	var args := OS.get_cmdline_user_args()
	if not args: return

	var search_dir := args[0]
	if not search_dir: return

	var dir_access := DirAccess.open(_m_executable_dir)
	if not dir_access:
		printerr("ERROR: Working directory cannot be opened! (" + error_string(DirAccess.get_open_error()) + ")")
		return

	if not dir_access.dir_exists(search_dir):
		printerr("ERROR: Directory not found! (\"" + search_dir + "\")")
		return

	print("Search directory: " + search_dir)
	CtrlSearchDir.text = search_dir
	#endregion

	# If an initial search directory was parsed, focus on the search term field instead
	CtrlSearchTerm.grab_focus()

# --------------------------------------------------------------------------------------------------
func _load_user_preferences() -> void:
	var file_path := _m_executable_dir + "/" + C_FILENAME_PREFERENCES
	if not FileAccess.file_exists(file_path):
		print("User preferences not set, skipping loading")
		return

	var preferences := ConfigFile.new()
	var return_code := preferences.load(file_path)
	if return_code != OK:
		print("Could not load user preferences (" + error_string(return_code) + ")")
		return

	# The preference file exists; let's parse it
	print("Loading user preferences...")
	CtrlSearchTerm.text = preferences.get_value(
		C_SECTION_PREVIOUS_SETTINGS, C_KEY_SEARCH_TERM, "") as String
	CtrlReplaceTerm.text = preferences.get_value(
		C_SECTION_PREVIOUS_SETTINGS, C_KEY_REPLACE_TERM, "") as String

	CtrlRecursive.button_pressed = preferences.get_value(
		C_SECTION_PREVIOUS_SETTINGS, C_KEY_SEARCH_RECURSIVELY, false) as bool
	CtrlCaseSensitive.button_pressed = preferences.get_value(
		C_SECTION_PREVIOUS_SETTINGS, C_KEY_SEARCH_CASE_SENSITIVE, false) as bool
	CtrlRegex.button_pressed = preferences.get_value(
		C_SECTION_PREVIOUS_SETTINGS, C_KEY_USE_REGEX, false) as bool
	CtrlIncludeBinary.button_pressed = preferences.get_value(
		C_SECTION_PREVIOUS_SETTINGS, C_KEY_INCLUDE_BINARY, false) as bool
	CtrlIncludeHidden.button_pressed = preferences.get_value(
		C_SECTION_PREVIOUS_SETTINGS, C_KEY_INCLUDE_HIDDEN, false) as bool

# --------------------------------------------------------------------------------------------------
func _save_user_preferences() -> void:
	print("Saving user preferences...")

	var preferences := ConfigFile.new()
	preferences.set_value(
		C_SECTION_PREVIOUS_SETTINGS, C_KEY_SEARCH_TERM, CtrlSearchTerm.text)
	preferences.set_value(
		C_SECTION_PREVIOUS_SETTINGS, C_KEY_REPLACE_TERM, CtrlReplaceTerm.text)

	preferences.set_value(
		C_SECTION_PREVIOUS_SETTINGS, C_KEY_SEARCH_RECURSIVELY, CtrlRecursive.button_pressed)
	preferences.set_value(
		C_SECTION_PREVIOUS_SETTINGS, C_KEY_SEARCH_CASE_SENSITIVE, CtrlCaseSensitive.button_pressed)
	preferences.set_value(
		C_SECTION_PREVIOUS_SETTINGS, C_KEY_USE_REGEX, CtrlRegex.button_pressed)
	preferences.set_value(
		C_SECTION_PREVIOUS_SETTINGS, C_KEY_INCLUDE_BINARY, CtrlIncludeBinary.button_pressed)
	preferences.set_value(
		C_SECTION_PREVIOUS_SETTINGS, C_KEY_INCLUDE_HIDDEN, CtrlIncludeHidden.button_pressed)

	var file_path := _m_executable_dir + "/" + C_FILENAME_PREFERENCES
	preferences.save(file_path)

# --------------------------------------------------------------------------------------------------
func _get_current_search_settings() -> T_Search_Settings:
	var settings                   := T_Search_Settings.new()
	settings.search_recursively    = CtrlRecursive.button_pressed
	settings.search_case_sensitive = CtrlCaseSensitive.button_pressed
	settings.use_regex             = CtrlRegex.button_pressed
	settings.include_binary        = CtrlIncludeBinary.button_pressed
	settings.include_hidden        = CtrlIncludeHidden.button_pressed

	return settings

# --------------------------------------------------------------------------------------------------
func _is_UI_input_valid(include_replace_term := false) -> bool:
	if not CtrlSearchDir.text:
		_set_status(T_Status.ERROR_NO_DIRECTORY)
		print("No directory specified!")
		return false

	var search_term := CtrlSearchTerm.text
	if not search_term:
		_set_status(T_Status.ERROR_NO_SEARCH_TERM)
		print("No search expression specified!")
		return false

	# Verify the regex search term
	if include_replace_term and CtrlRegex.button_pressed:
		_m_regex.compile(search_term)

		if not _m_regex.is_valid():
			_set_status(T_Status.ERROR_REGEX_SEARCH_TERM)
			return false

		# Verify the regex replace term
		var replace_term := CtrlReplaceTerm.text
		if not _regex_replace_matches_search(_m_regex, replace_term):
			_set_status(T_Status.ERROR_REGEX_REPLACE_TERM)
			return false

	return true

# --------------------------------------------------------------------------------------------------
func _regex_replace_matches_search(
	regex        : RegEx,
	replace_term : String
) -> bool:
	assert(regex.is_valid())

	var group_count := regex.get_group_count()

	# Determine referenced capture groups in the replace term
	var regex_replace := RegEx.create_from_string("(\\$[0-9]+)")
	var results := regex_replace.search_all(replace_term)

	for result in results:
		var group_ref := int(result.get_string().substr(1))

		if group_ref > group_count:
			return false

	return true

# --------------------------------------------------------------------------------------------------
func _enable_search_ctrls(state : bool) -> void:
	CtrlSearchDir.editable   = state
	CtrlSearchTerm.editable  = state
	CtrlReplaceTerm.editable = state

	var state_inv := not state
	CtrlButtonSearch.disabled  = state_inv
	CtrlButtonReplace.disabled = state_inv

	CtrlRecursive.disabled     = state_inv
	CtrlRegex.disabled         = state_inv
	CtrlIncludeHidden.disabled = state_inv
	CtrlCaseSensitive.disabled = state_inv
	CtrlIncludeBinary.disabled = state_inv

# --------------------------------------------------------------------------------------------------
func _set_status(status : T_Status) -> void:

	var count := _m_search_results.size()
	var default_colour := CtrlStatus.get_theme_color("default_color")

	CtrlStatus.clear()

	match status:
		T_Status.IDLE:
			CtrlStatus.push_color(Color(0, 1, 0, 1))
			CtrlStatus.append_text("Idle")

		T_Status.SEARCHING:
			CtrlStatus.push_color(Color(1, 1, 0, 1))
			CtrlStatus.append_text("Searching... ")

			CtrlStatus.push_color(default_colour)
			CtrlStatus.append_text("(" + str(count) + " results; searched " + str(_m_iterations) + " files)")

		T_Status.DONE:
			CtrlStatus.push_color(Color(0, 1, 0, 1))
			CtrlStatus.append_text("Done ")

			CtrlStatus.push_color(default_colour)
			CtrlStatus.append_text("(" + str(count) + " results)")

		T_Status.ERROR_NO_DIRECTORY:
			CtrlStatus.push_color(Color(1, 0, 0, 1))
			CtrlStatus.append_text("ERROR: No search directory specified!")

		T_Status.ERROR_INVALID_DIRECTORY:
			CtrlStatus.push_color(Color(1, 0, 0, 1))
			CtrlStatus.append_text("ERROR: invalid search directory!")

		T_Status.ERROR_NO_SEARCH_TERM:
			CtrlStatus.push_color(Color(1, 0, 0, 1))
			CtrlStatus.append_text("ERROR: No search term specified!")

		T_Status.ERROR_REGEX_SEARCH_TERM:
			CtrlStatus.push_color(Color(1, 0, 0, 1))
			CtrlStatus.append_text("ERROR: invalid regex search term!")

		T_Status.ERROR_REGEX_REPLACE_TERM:
			CtrlStatus.push_color(Color(1, 0, 0, 1))
			CtrlStatus.append_text("ERROR: invalid regex replace term!")

		T_Status.ERROR_ITERATIONS:
			CtrlStatus.push_color(Color(1, 0, 0, 1))
			CtrlStatus.append_text("Aborted: iterations limit exceeded! ")

			CtrlStatus.push_color(default_colour)
			CtrlStatus.append_text("(" + str(count) + " results)")

# --------------------------------------------------------------------------------------------------
func _gfind_search(
	directory             : String,
	search_term           : String,
	settings              : T_Search_Settings,
	do_replace            : bool = false,
	replace_term          : String = ""
) -> void:
	_clear_table(true)
	_m_iterations = 0

	var prev_render_time  := Time.get_ticks_msec()
	var queue             := [[directory, "."]]
	var entry_data        : Array
	var entry             : DirAccess
	var entry_path        : String
	var entry_path_parent : String
	var next_name      	  : String
	var next_path      	  : String
	var next_path_parent  : String

	if not DirAccess.dir_exists_absolute(directory):
		_set_status(T_Status.ERROR_INVALID_DIRECTORY)
		return

	if settings.use_regex:
		if not settings.search_case_sensitive:
			search_term = "(?i)" + search_term
		_m_regex.compile(search_term)

		if not _m_regex.is_valid():
			_set_status(T_Status.ERROR_REGEX_SEARCH_TERM)
			return


	while not queue.is_empty():
		entry_data = queue.pop_front()
		entry = DirAccess.open(entry_data[0])
		if not entry: continue

		entry_path        = entry.get_current_dir().simplify_path()
		entry_path_parent = entry_data[1]

		entry.include_hidden = settings.include_hidden
		entry.list_dir_begin()

		while true:
			next_name = entry.get_next()
			if not next_name:
				_set_status(T_Status.DONE)
				break

			_m_iterations += 1
			if _m_iterations > C_MAX_SEARCH_ITERATIONS:
				printerr("Aborting: iterations limit reached! (" + str(C_MAX_SEARCH_ITERATIONS) + ")\n"
					+ "This could be caused by a recursive symbolic links/junction within the "
					+ "search directory."
				)
				_set_status(T_Status.ERROR_ITERATIONS)
				break

			# If it's a folder (this includes symbolic links), add it to the queue for further
			# exploration
			next_path        = entry_path + "/" + next_name
			next_path_parent = entry_path_parent + "/" + next_name
			if entry.dir_exists(next_name):
				if settings.search_recursively:
					queue.push_back([next_path, next_path_parent])
				continue

			# Not a folder, so it must be a file. Test it for the provided search term.
			_gfind_search_in_file(
				next_path,
				next_path_parent,
				search_term,
				settings,
				do_replace,
				replace_term
			)
			# Periodically let the engine render the UI
			if Time.get_ticks_msec() - prev_render_time > C_MAX_INTERVAL_BETWEEN_FRAMES:
				_set_status(T_Status.SEARCHING)

				#await Engine.get_main_loop().process_frame
				await RenderingServer.frame_post_draw

				prev_render_time = Time.get_ticks_msec()

		entry.list_dir_end()

	# Final step
	_sort_results()

# --------------------------------------------------------------------------------------------------
func _gfind_search_in_file(
	file_path       : String,
	file_path_short : String,
	search_term     : String,
	settings        : T_Search_Settings,
	do_replace      : bool = false,
	replace_term    : String = ""
) -> void:

	#region File validation
	var file := FileAccess.open(file_path, FileAccess.READ)
	if not file:
		#print("Skipping file search (" + error_string(FileAccess.get_open_error()) + "): " + file_path)
		return

	var file_size := file.get_length()
	if file_size == 0:
		#print("Skipping file search (0 size): " + file_path)
		return

	var search_term_length := search_term.length()
	var binary_test_buffer := file.get_buffer(C_BINARY_TEST_BUFFER_LENGTH)
	var _is_binary_file    := _is_data_binary(binary_test_buffer)
	if not settings.include_binary and _is_binary_file:
		#print("Skipping file search (contains binary data): " + file_path)
		return
	#endregion

	file.seek(0)
	var file_contents_raw := file.get_buffer(file_size)
	var file_contents     := file_contents_raw.get_string_from_utf8()
	var find_pos          := 0
	var matches           := 0
	var offsets           : Array[int]
	var previews          : Array[T_Preview]

	#region Search file contents
	# Regex searches only make sense on text files, not binary ones.
	if settings.use_regex and not _is_binary_file:
		var regex_results := _m_regex.search_all(file_contents)
		matches = regex_results.size()

		if matches > 0 and not do_replace:
			var regex_result : RegExMatch

			for i in min(matches, C_MAX_MATCH_PREVIEWS): # 0 .. min - 1
				regex_result = regex_results[i]
				previews.push_back(_make_preview(
					file_contents,
					regex_result.get_start(),
					regex_result.get_end()
				))

	else:
		while true:
			if settings.search_case_sensitive:
				find_pos = file_contents.find(search_term, find_pos)
			else:
				find_pos = file_contents.findn(search_term, find_pos)

			if find_pos >= 0:
				offsets.push_back(find_pos)
	
				if matches < C_MAX_MATCH_PREVIEWS:
					previews.push_back(_make_preview(
						file_contents,
						find_pos,
						find_pos + search_term_length
					))

				find_pos += 1
				matches  += 1
			else:
				# Add a final slice
				offsets.push_back(file_size)
				break

	if matches == 0: return
	file.close()
	#endregion

	# Found at least one match; prepare the result
	var result       := T_Search_Result.new()
	result.file_name  = file_path_short.get_file()
	result.path       = file_path
	result.path_short = file_path_short.get_base_dir()
	result.matches    = matches

	#region Replace file contents
	if do_replace:
		file = FileAccess.open(file_path, FileAccess.WRITE)

		# We have write permission, let's replace the contents
		if file:
			if settings.use_regex:
				var replaced_contents := _m_regex.sub(file_contents, replace_term, true)
				if replaced_contents:
					file.store_string(replaced_contents)
				else:
					push_error("Regex content replace failed! This should not happen!")

			else:
				var pos_start : int = 0
				var slices    : Array[String]

				for offset in offsets:
					slices.push_back(file_contents.substr(pos_start, offset - pos_start))

					if offset >= file_size: break

					slices.push_back(replace_term)
					pos_start = offset + search_term_length
				file.store_string("".join(slices))

			file_size = file.get_length()
			file.close()

		# File cannot be written to, but we can't return because we still want to log the result
		else:
			print("Could not replace in file (" + error_string(FileAccess.get_open_error()) + "): " + file_path)
	#endregion

	result.size     = file_size
	result.previews = previews
	_m_search_results.push_back(result)

# --------------------------------------------------------------------------------------------------
func _clear_table(clear_results : bool = false) -> void:
	CtrlTable.clear()
	CtrlTable.create_item()

	if clear_results:
		_m_search_results = []

# --------------------------------------------------------------------------------------------------
func _add_result(result : T_Search_Result) -> void:
	_m_search_results.push_front(result)
	_add_entry_from_result(result)

# --------------------------------------------------------------------------------------------------
func _add_entry_from_result(result : T_Search_Result) -> void:
	var entry := CtrlTable.create_item()
	entry.set_metadata(C_COLUMN_PATH_SHORT, result.path)

	entry.set_text(C_COLUMN_FILENAME,   result.file_name)
	entry.set_text(C_COLUMN_MATCHES,    str(result.matches))
	entry.set_text(C_COLUMN_SIZE,       _file_size_to_str(result.size))
	entry.set_text(C_COLUMN_PATH_SHORT, result.path_short)

	entry.set_text_alignment(C_COLUMN_MATCHES, HORIZONTAL_ALIGNMENT_RIGHT)
	entry.set_text_alignment(C_COLUMN_SIZE,    HORIZONTAL_ALIGNMENT_RIGHT)

	# TODO: Handle extended previews
	var newline     := PackedByteArray([10]).get_string_from_ascii()
	var preview_str := ""
	for preview in result.previews:
		preview_str += preview.left + preview.text + preview.right + newline
	#preview_str = " "

	entry.set_tooltip_text(C_COLUMN_FILENAME,   preview_str)
	entry.set_tooltip_text(C_COLUMN_MATCHES,    preview_str)
	entry.set_tooltip_text(C_COLUMN_SIZE,       str(result.size) + " Bytes")
	entry.set_tooltip_text(C_COLUMN_PATH_SHORT, result.path)

# --------------------------------------------------------------------------------------------------
func _sort_results() -> void:

	var _results_copy := _m_search_results.duplicate()
	_results_copy.sort_custom(_sort_column_entry)

	_clear_table(true)
	for result in _results_copy:
		_add_result(result)

# --------------------------------------------------------------------------------------------------
func _sort_column_entry(left, right : T_Search_Result) -> bool:

	var value_left  : Variant
	var value_right : Variant

	match _m_column_to_sort:
		C_COLUMN_FILENAME:
			value_left  = left.file_name
			value_right = right.file_name

		C_COLUMN_MATCHES:
			value_left  = left.matches
			value_right = right.matches

		C_COLUMN_SIZE:
			value_left  = left.size
			value_right = right.size

		C_COLUMN_PATH_SHORT:
			value_left  = left.path_short
			value_right = right.path_short

	if _m_invert_sort_order:
		return (value_left < value_right)
	else:
		return (value_left > value_right)

# --------------------------------------------------------------------------------------------------
func _file_size_to_str(size : int) -> String:

	var size_comp    := 1
	var prefix_index := 0

	while size_comp * 1000 < size:
		prefix_index += 1
		size_comp    = size_comp * 1000

	var prefix : String
	match prefix_index:
		0: prefix = ""
		1: prefix = "k"
		2: prefix = "M"
		3: prefix = "G"
		4: prefix = "T"
		_: prefix = "P"

	# If at least one SI prefix was needed, convert to float and display 3 digits
	if prefix_index > 0:
		var size_float := float(size) / float(size_comp)
		var decimals   := 3 - str(floor(size_float)).length()
		return str(size_float).pad_decimals(decimals) + " " + prefix + "B"

	# Otherwise, use the integer size
	else:
		return str(size) + " B"

# --------------------------------------------------------------------------------------------------
func _make_preview(
	file_contents    : String,
	start            : int,
	end              : int
) -> T_Preview:
	var preview := T_Preview.new()

	if not file_contents:
		return preview

	preview.text = file_contents.substr(start, end - start)

	#pad   = max(start - preview_padding, 0)
	#match_length  = result.get_end() - match_start + preview_padding
	#preview.text  = _sanitise_preview(
		#file_contents.substr(match_start, match_length),
		#preview_padding
	#)

	return preview

# --------------------------------------------------------------------------------------------------
func _is_data_binary(buffer : PackedByteArray) -> bool:

	# Look for non-printable characters within the first N bytes
	for byte in buffer:
		if (byte < 32 and not byte in [9, 10, 13]): # Tab, line feed, carriage return
			return true

	return false

# --------------------------------------------------------------------------------------------------
func _sanitise_preview_pad(
	text : String,
	side : bool # false for left pad, true for right pad
) -> String:
	if not text: return ""

	var length : int = min(C_MAX_PAD_LENGTH, text.length())
	var pos_i  : int

	# Catch the first LF/CR char in the left pad, iterating backward
	if not side:
		for i in length:
			pos_i = length - i - 1

			if text.unicode_at(pos_i) in [10, 13]:
				return text.substr(pos_i)

	# Catch the first LF/CR char in the right pad, iterating forward
	else:
		for i in length:
			pos_i = i

			if text.unicode_at(pos_i) in [10, 13]:
				return text.substr(0, pos_i)

	return text
