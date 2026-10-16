class_name AboutDialog
extends AcceptDialog
## Help > About LadderLab: version, copyright and the GPL notice, the full
## license text, and the licenses of Godot Engine and its third-party parts
## (their notices must ship with every build).

const COPYRIGHT: String = "Copyright © 2026 Jaroslav Krnínský"
## Shipped next to the program (include_filter of the export preset).
const LICENSE_PATH: String = "res://LICENSE"
const GPL_URL: String = "https://www.gnu.org/licenses/gpl-3.0.html"

var _tabs: TabContainer
var _version: Label
var _summary: Label
var _notice: Label
var _website: LinkButton
var _license: TextEdit
var _third_party: TextEdit


func _init() -> void:
	min_size = Vector2i(640, 500)
	_tabs = TabContainer.new()
	_tabs.custom_minimum_size = Vector2(600, 420)
	add_child(_tabs)

	var about: VBoxContainer = VBoxContainer.new()
	about.add_theme_constant_override("separation", 10)
	_tabs.add_child(about)
	var head: HBoxContainer = HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	about.add_child(head)
	var logo: TextureRect = TextureRect.new()
	logo.texture = load("res://icon.svg")
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.custom_minimum_size = Vector2(64, 64)
	head.add_child(logo)
	var names: VBoxContainer = VBoxContainer.new()
	names.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_child(names)
	var brand: Label = _text(names, "BrandLabel")
	brand.text = "LadderLab"
	_version = _text(names, "MutedLabel")
	_summary = _text(about)
	var copyright: Label = _text(about)
	copyright.text = COPYRIGHT
	_notice = _text(about)
	_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_website = LinkButton.new()
	_website.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_website.focus_mode = Control.FOCUS_NONE
	_website.pressed.connect(func() -> void: OS.shell_open(ReleaseCheck.PROJECT_PAGE))
	about.add_child(_website)

	_license = _page()
	_third_party = _page()
	_third_party.text = _third_party_text()


func _text(parent: Control, variation: String = "") -> Label:
	var label: Label = Label.new()
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.theme_type_variation = variation
	parent.add_child(label)
	return label


## A read-only text page in its own tab.
func _page() -> TextEdit:
	var page: TextEdit = TextEdit.new()
	page.editable = false
	page.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	page.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_tabs.add_child(page)
	return page


## Sets every text in the current language and shows the dialog.
func open() -> void:
	retranslate()
	_tabs.current_tab = 0
	popup_centered()


func retranslate() -> void:
	title = tr("About LadderLab")
	ok_button_text = tr("OK")
	_tabs.set_tab_title(0, tr("About"))
	_tabs.set_tab_title(1, tr("License"))
	_tabs.set_tab_title(2, tr("Third-party licenses"))
	_version.text = tr("Version %s") % ReleaseCheck.current_version()
	_summary.text = tr("Relay control circuit simulator")
	_notice.text = tr("LadderLab is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License, version 3 or later. It comes with ABSOLUTELY NO WARRANTY.")
	_website.text = tr("Project website")
	if FileAccess.file_exists(LICENSE_PATH):
		_license.text = FileAccess.get_file_as_string(LICENSE_PATH)
	else:
		_license.text = tr("The license text is missing; see %s") % GPL_URL


## Godot Engine's license and the copyright and license of each of its
## third-party components, as the engine reports them.
func _third_party_text() -> String:
	var lines: PackedStringArray = ["Godot Engine", "", Engine.get_license_text(), ""]
	for component: Dictionary in Engine.get_copyright_info():
		lines.append("— %s" % component["name"])
		for part: Dictionary in component["parts"]:
			for line: String in part["copyright"]:
				lines.append("© " + line)
			lines.append("License: " + str(part["license"]))
		lines.append("")
	var texts: Dictionary = Engine.get_license_info()
	for license: String in texts:
		lines.append("=== %s ===" % license)
		lines.append("")
		lines.append(texts[license])
		lines.append("")
	return "\n".join(lines)
