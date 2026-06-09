@tool
extends Control

# ─── Costanti ────────────────────────────────────────────────
const API_URL       := "https://api.anthropic.com/v1/messages"
const API_VERSION   := "2023-06-01"
const MODEL         := "claude-sonnet-4-6"
const MAX_TOKENS    := 2048
const SETTINGS_KEY  := "claude_assistant/api_key"
const TEMP_SCRIPT   := "res://addons/claude_assistant/_claude_temp.gd"
const HISTORY_FILE  := "res://addons/claude_assistant/history.json"
const SNIPPETS_FILE := "res://addons/claude_assistant/snippets.json"
const MAX_HISTORY   := 40

# ─── Riferimento all'editor (impostato da plugin.gd) ─────────
var editor_plugin = null

# ─── Colori ──────────────────────────────────────────────────
const COLOR_USER    := Color(0.20, 0.55, 0.90)
const COLOR_CLAUDE  := Color(0.25, 0.80, 0.60)
const COLOR_ERROR   := Color(0.90, 0.35, 0.35)
const COLOR_SYSTEM  := Color(0.65, 0.65, 0.65)
const COLOR_BUG     := Color(0.95, 0.60, 0.10)
const COLOR_SNIPPET := Color(0.75, 0.45, 0.95)

# ─── Nodi UI ─────────────────────────────────────────────────
var tab_container     : TabContainer
var scroll_container  : ScrollContainer
var messages_box      : VBoxContainer
var input_field       : TextEdit
var send_button       : Button
var settings_panel    : PanelContainer
var api_key_field     : LineEdit
var http_request      : HTTPRequest
var spinner_label     : Label
var error_panel       : PanelContainer
var error_input_field : TextEdit
var snippets_list     : VBoxContainer
var script_label      : Label

# ─── Stato ───────────────────────────────────────────────────
var conversation_history : Array = []
var snippets_data        : Array = []
var is_waiting           : bool  = false
var api_key              : String = ""

# ─────────────────────────────────────────────────────────────
func _init() -> void:
	custom_minimum_size = Vector2(300, 160)

func _ready() -> void:
	_build_ui()
	_load_api_key()
	_load_snippets()
	_load_history()

# ─────────────────────────────────────────────────────────────
#  Costruzione UI
# ─────────────────────────────────────────────────────────────
func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	tab_container = TabContainer.new()
	tab_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(tab_container)

	# ══════════════ TAB 1: CHAT ══════════════
	var chat_root := VBoxContainer.new()
	chat_root.name = "💬 Chat"
	tab_container.add_child(chat_root)

	# ── Toolbar ──
	var toolbar := HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 4)
	chat_root.add_child(toolbar)

	var title_lbl := Label.new()
	title_lbl.text = "✦ Godo4NewbiAI"
	title_lbl.add_theme_color_override("font_color", COLOR_CLAUDE)
	title_lbl.add_theme_font_size_override("font_size", 13)
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(title_lbl)

	var script_btn := Button.new()
	script_btn.text = "📖"
	script_btn.tooltip_text = "Invia lo script aperto a Claude come contesto"
	script_btn.pressed.connect(_inject_current_script)
	toolbar.add_child(script_btn)

	var bug_btn := Button.new()
	bug_btn.text = "🐛"
	bug_btn.tooltip_text = "Incolla un errore da Output"
	bug_btn.pressed.connect(_toggle_error_panel)
	toolbar.add_child(bug_btn)

	var settings_btn := Button.new()
	settings_btn.text = "⚙"
	settings_btn.tooltip_text = "API Key"
	settings_btn.pressed.connect(_toggle_settings)
	toolbar.add_child(settings_btn)

	var clear_btn := Button.new()
	clear_btn.text = "🗑"
	clear_btn.tooltip_text = "Cancella conversazione"
	clear_btn.pressed.connect(_clear_conversation)
	toolbar.add_child(clear_btn)

	# ── Label script attivo ──
	script_label = Label.new()
	script_label.add_theme_color_override("font_color", COLOR_SYSTEM)
	script_label.add_theme_font_size_override("font_size", 10)
	script_label.visible = false
	chat_root.add_child(script_label)

	# ── Area messaggi ──
	scroll_container = ScrollContainer.new()
	scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	chat_root.add_child(scroll_container)

	messages_box = VBoxContainer.new()
	messages_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	messages_box.add_theme_constant_override("separation", 6)
	scroll_container.add_child(messages_box)

	# ── Spinner ──
	spinner_label = Label.new()
	spinner_label.text = "⏳ Claude sta scrivendo..."
	spinner_label.add_theme_color_override("font_color", COLOR_SYSTEM)
	spinner_label.visible = false
	chat_root.add_child(spinner_label)

	# ── Pannello errore ──
	error_panel = PanelContainer.new()
	error_panel.visible = false
	chat_root.add_child(error_panel)

	var ev := VBoxContainer.new()
	error_panel.add_child(ev)

	var el := Label.new()
	el.text = "🐛 Incolla errore dal pannello Output:"
	el.add_theme_color_override("font_color", COLOR_BUG)
	ev.add_child(el)

	error_input_field = TextEdit.new()
	error_input_field.custom_minimum_size = Vector2(0, 70)
	error_input_field.placeholder_text = "Incolla qui l'errore..."
	error_input_field.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	ev.add_child(error_input_field)

	var ebr := HBoxContainer.new()
	ev.add_child(ebr)
	var send_err := Button.new()
	send_err.text = "🐛 Manda a Claude"
	send_err.pressed.connect(_on_send_error_pressed)
	ebr.add_child(send_err)
	var cancel_err := Button.new()
	cancel_err.text = "Annulla"
	cancel_err.pressed.connect(func(): error_panel.visible = false)
	ebr.add_child(cancel_err)

	# ── Pannello settings ──
	settings_panel = PanelContainer.new()
	settings_panel.visible = false
	chat_root.add_child(settings_panel)

	var sv := VBoxContainer.new()
	settings_panel.add_child(sv)
	var kl := Label.new()
	kl.text = "API Key Anthropic:"
	sv.add_child(kl)
	api_key_field = LineEdit.new()
	api_key_field.secret = true
	api_key_field.placeholder_text = "sk-ant-..."
	api_key_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sv.add_child(api_key_field)
	var save_key := Button.new()
	save_key.text = "Salva"
	save_key.pressed.connect(_save_api_key)
	sv.add_child(save_key)

	# ── Input ──
	var input_row := HBoxContainer.new()
	input_row.add_theme_constant_override("separation", 4)
	chat_root.add_child(input_row)

	input_field = TextEdit.new()
	input_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	input_field.custom_minimum_size = Vector2(0, 55)
	input_field.placeholder_text = "Chiedi qualcosa... (Ctrl+Invio)"
	input_field.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	input_field.gui_input.connect(_on_input_gui_input)
	input_row.add_child(input_field)

	send_button = Button.new()
	send_button.text = "▶"
	send_button.tooltip_text = "Invia"
	send_button.pressed.connect(_on_send_pressed)
	input_row.add_child(send_button)

	# ── HTTPRequest ──
	http_request = HTTPRequest.new()
	http_request.request_completed.connect(_on_request_completed)
	add_child(http_request)

	# ══════════════ TAB 2: SNIPPETS ══════════════
	var snip_root := VBoxContainer.new()
	snip_root.name = "💾 Snippet"
	tab_container.add_child(snip_root)

	var snip_header := Label.new()
	snip_header.text = "Snippet salvati — clicca 📋 su un blocco codice per salvarlo"
	snip_header.add_theme_color_override("font_color", COLOR_SYSTEM)
	snip_header.add_theme_font_size_override("font_size", 11)
	snip_header.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	snip_root.add_child(snip_header)

	var snip_scroll := ScrollContainer.new()
	snip_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	snip_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	snip_root.add_child(snip_scroll)

	snippets_list = VBoxContainer.new()
	snippets_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	snippets_list.add_theme_constant_override("separation", 8)
	snip_scroll.add_child(snippets_list)

# ─────────────────────────────────────────────────────────────
#  Lettura script aperto
# ─────────────────────────────────────────────────────────────
func _inject_current_script() -> void:
	if editor_plugin == null:
		_add_message("Sistema", "⚠️ Editor non disponibile.", COLOR_ERROR)
		return

	var se = editor_plugin.get_editor_interface().get_script_editor()
	var current = se.get_current_script()
	if current == null:
		_add_message("Sistema", "⚠️ Nessuno script aperto nell'editor.", COLOR_SYSTEM)
		return

	var path  : String = current.resource_path
	var source: String = current.source_code
	var msg   : String = "Sto lavorando su questo script, tienilo come contesto:\n\n📄 %s\n\n```gdscript\n%s\n```" % [path, source]

	script_label.text = "📖 Contesto: " + path.get_file()
	script_label.visible = true

	_add_message("Tu 📖", "Ho condiviso lo script: " + path.get_file(), COLOR_USER)
	conversation_history.append({"role": "user", "content": msg})
	_save_history()
	_add_message("Sistema", "✅ Script inviato come contesto. Ora puoi fare domande su di esso.", COLOR_SYSTEM)

# ─────────────────────────────────────────────────────────────
#  Pannello errore
# ─────────────────────────────────────────────────────────────
func _toggle_error_panel() -> void:
	error_panel.visible = !error_panel.visible
	settings_panel.visible = false
	if error_panel.visible:
		error_input_field.text = ""
		error_input_field.grab_focus()

func _on_send_error_pressed() -> void:
	var t := error_input_field.text.strip_edges()
	if t.is_empty(): return
	error_panel.visible = false
	error_input_field.text = ""
	var msg := "Ho questo errore in Godot, puoi aiutarmi?\n\n```\n%s\n```" % t
	_add_message("Tu 🐛", msg, COLOR_BUG)
	conversation_history.append({"role": "user", "content": msg})
	_send_to_claude()

# ─────────────────────────────────────────────────────────────
#  API Key
# ─────────────────────────────────────────────────────────────
func _load_api_key() -> void:
	if ProjectSettings.has_setting(SETTINGS_KEY):
		api_key = ProjectSettings.get_setting(SETTINGS_KEY)
		if api_key_field: api_key_field.text = api_key

func _save_api_key() -> void:
	api_key = api_key_field.text.strip_edges()
	ProjectSettings.set_setting(SETTINGS_KEY, api_key)
	ProjectSettings.save()
	settings_panel.visible = false
	_add_message("Sistema", "✅ API Key salvata!", COLOR_SYSTEM)

func _toggle_settings() -> void:
	settings_panel.visible = !settings_panel.visible
	error_panel.visible = false

# ─────────────────────────────────────────────────────────────
#  Invio messaggio
# ─────────────────────────────────────────────────────────────
func _on_input_gui_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ENTER and event.ctrl_pressed:
			_on_send_pressed()
			get_viewport().set_input_as_handled()

func _on_send_pressed() -> void:
	var text := input_field.text.strip_edges()
	if text.is_empty() or is_waiting: return
	if api_key.is_empty():
		_add_message("Sistema", "⚠️ Inserisci la API Key (⚙).", COLOR_ERROR)
		settings_panel.visible = true
		return
	input_field.text = ""
	_add_message("Tu", text, COLOR_USER)
	conversation_history.append({"role": "user", "content": text})
	_send_to_claude()

func _send_to_claude() -> void:
	is_waiting = true
	send_button.disabled = true
	spinner_label.visible = true

	var headers := [
		"Content-Type: application/json",
		"x-api-key: " + api_key,
		"anthropic-version: " + API_VERSION
	]

	var system_prompt := """Sei Godo4NewbiAI, un assistente AI esperto di Godot 4 integrato direttamente nell'editor come plugin.
Rispondi sempre in italiano. Sei preciso, conciso e pratico.

REGOLA FONDAMENTALE — EDITORSCRIPT:
Quando l'utente vuole creare scene, nodi, risorse o modificare il progetto, genera SEMPRE un EditorScript eseguibile con questo formato esatto:

```gdscript
@tool
extends EditorScript

func _run() -> void:
	# codice qui
	# usa get_editor_interface() per accedere all'editor
```

COSA PUOI FARE CON EDITORSCRIPT:
- Creare scene e nodi con proprietà (posizione, scala, colori, collision layer...)
- Salvare scene: get_editor_interface().save_scene()
- Aprire scene: get_editor_interface().open_scene_from_path(path)
- Creare file di risorse
- Modificare nodi esistenti nella scena aperta

Per domande teoriche, bug e spiegazioni: rispondi con testo e GDScript standard.
Non aggiungere mai prose lunghe — vai dritto alla soluzione."""

	var body := JSON.stringify({
		"model": MODEL,
		"max_tokens": MAX_TOKENS,
		"system": system_prompt,
		"messages": conversation_history
	})

	var err := http_request.request(API_URL, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		_on_error("Errore connessione (codice %d)" % err)

func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	is_waiting = false
	send_button.disabled = false
	spinner_label.visible = false

	if result != HTTPRequest.RESULT_SUCCESS:
		_on_error("Richiesta fallita (result=%d)" % result)
		return
	if response_code != 200:
		_on_error("HTTP %d — %s" % [response_code, body.get_string_from_utf8()])
		return

	var json := JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		_on_error("Errore parsing risposta.")
		return

	var data : Dictionary = json.get_data()
	if not data.has("content") or data["content"].is_empty():
		_on_error("Risposta vuota.")
		return

	var reply : String = data["content"][0]["text"]
	conversation_history.append({"role": "assistant", "content": reply})
	_save_history()
	_render_response(reply)

func _on_error(msg: String) -> void:
	is_waiting = false
	send_button.disabled = false
	spinner_label.visible = false
	_add_message("Errore", msg, COLOR_ERROR)

# ─────────────────────────────────────────────────────────────
#  Rendering risposta con blocchi di codice
# ─────────────────────────────────────────────────────────────
func _render_response(full_text: String) -> void:
	var bubble := PanelContainer.new()
	var vbox := VBoxContainer.new()
	bubble.add_child(vbox)

	var sender_lbl := Label.new()
	sender_lbl.text = "✦ Godo4NewbiAI"
	sender_lbl.add_theme_color_override("font_color", COLOR_CLAUDE)
	sender_lbl.add_theme_font_size_override("font_size", 11)
	vbox.add_child(sender_lbl)

	for seg in _parse_segments(full_text):
		if seg["type"] == "text":
			var te := _make_selectable_text(seg["content"])
			vbox.add_child(te)
		else:
			var code : String = seg["content"]
			var is_es  := "extends EditorScript" in code

			var cpanel := PanelContainer.new()
			var cvbox  := VBoxContainer.new()
			cpanel.add_child(cvbox)

			var ch := Label.new()
			ch.text = "📄 EditorScript — premi ▶ per eseguire" if is_es else "📝 GDScript"
			ch.add_theme_color_override("font_color", COLOR_CLAUDE if is_es else COLOR_SYSTEM)
			ch.add_theme_font_size_override("font_size", 11)
			cvbox.add_child(ch)

			var ce := TextEdit.new()
			ce.text = code
			ce.editable = false
			ce.selecting_enabled = true
			ce.context_menu_enabled = true
			ce.wrap_mode = TextEdit.LINE_WRAPPING_NONE
			ce.scroll_fit_content_height = true
			ce.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			cvbox.add_child(ce)

			var br := HBoxContainer.new()
			cvbox.add_child(br)

			var cb := Button.new()
			cb.text = "📋 Copia"
			cb.flat = true
			cb.pressed.connect(func(): DisplayServer.clipboard_set(code))
			br.add_child(cb)

			var sb := Button.new()
			sb.text = "💾 Salva snippet"
			sb.flat = true
			sb.pressed.connect(func(): _prompt_save_snippet(code))
			br.add_child(sb)

			if is_es:
				var rb := Button.new()
				rb.text = "▶ Esegui in Godot"
				rb.pressed.connect(func(): _execute_editor_script(code))
				br.add_child(rb)

			vbox.add_child(cpanel)

	messages_box.add_child(bubble)
	await get_tree().process_frame
	scroll_container.scroll_vertical = scroll_container.get_v_scroll_bar().max_value

func _parse_segments(text: String) -> Array:
	var segments : Array = []
	var lines    := text.split("\n")
	var in_block := false
	var block    := ""
	var prose    := ""

	for line in lines:
		if line.begins_with("```"):
			if not in_block:
				if prose.strip_edges() != "":
					segments.append({"type": "text", "content": prose.strip_edges()})
					prose = ""
				in_block = true
				block = ""
			else:
				segments.append({"type": "code", "content": block.strip_edges()})
				block = ""
				in_block = false
		elif in_block:
			block += line + "\n"
		else:
			prose += line + "\n"

	if prose.strip_edges() != "":
		segments.append({"type": "text", "content": prose.strip_edges()})
	return segments

func _make_selectable_text(content: String) -> TextEdit:
	var te := TextEdit.new()
	te.text = content
	te.editable = false
	te.selecting_enabled = true
	te.context_menu_enabled = true
	te.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	te.scroll_fit_content_height = true
	te.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	te.add_theme_stylebox_override("normal",    StyleBoxEmpty.new())
	te.add_theme_stylebox_override("focus",     StyleBoxEmpty.new())
	te.add_theme_stylebox_override("read_only", StyleBoxEmpty.new())
	return te

# ─────────────────────────────────────────────────────────────
#  Esecuzione EditorScript
# ─────────────────────────────────────────────────────────────
func _execute_editor_script(code: String) -> void:
	var file := FileAccess.open(TEMP_SCRIPT, FileAccess.WRITE)
	if file == null:
		_add_message("Sistema", "❌ Impossibile salvare lo script temporaneo.", COLOR_ERROR)
		return
	file.store_string(code)
	file.close()

	var script = load(TEMP_SCRIPT)
	if script == null:
		_add_message("Sistema", "❌ Errore nel caricamento. Controlla la sintassi.", COLOR_ERROR)
		return
	if not script.can_instantiate():
		_add_message("Sistema", "❌ Script non istanziabile.", COLOR_ERROR)
		return

	var instance = script.new()
	if not instance is EditorScript:
		_add_message("Sistema", "⚠️ Lo script non estende EditorScript.", COLOR_ERROR)
		return

	_add_message("Sistema", "⚙️ Esecuzione in corso...", COLOR_SYSTEM)
	instance._run()
	_add_message("Sistema", "✅ Fatto! Controlla la scena.", COLOR_CLAUDE)

# ─────────────────────────────────────────────────────────────
#  Snippet Library
# ─────────────────────────────────────────────────────────────
func _prompt_save_snippet(code: String) -> void:
	# Dialogo nome snippet
	var dialog := AcceptDialog.new()
	dialog.title = "Salva Snippet"
	dialog.size = Vector2(320, 120)

	var vb := VBoxContainer.new()
	var lbl := Label.new()
	lbl.text = "Nome per questo snippet:"
	vb.add_child(lbl)
	var line := LineEdit.new()
	line.placeholder_text = "es. Movimento personaggio"
	vb.add_child(line)
	dialog.add_child(vb)

	add_child(dialog)
	dialog.confirmed.connect(func():
		var name := line.text.strip_edges()
		if name.is_empty(): name = "Snippet %d" % (snippets_data.size() + 1)
		_add_snippet(name, code)
		dialog.queue_free()
	)
	dialog.canceled.connect(func(): dialog.queue_free())
	dialog.popup_centered()

func _add_snippet(name: String, code: String) -> void:
	snippets_data.append({
		"name": name,
		"code": code,
		"date": Time.get_datetime_string_from_system()
	})
	_save_snippets()
	_refresh_snippets_ui()
	_add_message("Sistema", "💾 Snippet \"%s\" salvato!" % name, COLOR_SNIPPET)

func _refresh_snippets_ui() -> void:
	for child in snippets_list.get_children():
		child.queue_free()

	if snippets_data.is_empty():
		var empty := Label.new()
		empty.text = "Nessuno snippet salvato.\nUsa 💾 su un blocco codice per salvarlo."
		empty.add_theme_color_override("font_color", COLOR_SYSTEM)
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		snippets_list.add_child(empty)
		return

	for i in snippets_data.size():
		var snip : Dictionary = snippets_data[i]
		var card := PanelContainer.new()
		var cv   := VBoxContainer.new()
		card.add_child(cv)

		var header := HBoxContainer.new()
		cv.add_child(header)

		var name_lbl := Label.new()
		name_lbl.text = "💾 " + snip["name"]
		name_lbl.add_theme_color_override("font_color", COLOR_SNIPPET)
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		header.add_child(name_lbl)

		var date_lbl := Label.new()
		date_lbl.text = snip["date"].substr(0, 10)
		date_lbl.add_theme_color_override("font_color", COLOR_SYSTEM)
		date_lbl.add_theme_font_size_override("font_size", 10)
		header.add_child(date_lbl)

		var preview := TextEdit.new()
		preview.text = snip["code"]
		preview.editable = false
		preview.selecting_enabled = true
		preview.context_menu_enabled = true
		preview.custom_minimum_size = Vector2(0, 80)
		preview.scroll_fit_content_height = false
		preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cv.add_child(preview)

		var btn_row := HBoxContainer.new()
		cv.add_child(btn_row)

		var copy_btn := Button.new()
		copy_btn.text = "📋 Copia"
		copy_btn.flat = true
		var code_ref: String = snip["code"]
		copy_btn.pressed.connect(func(): DisplayServer.clipboard_set(code_ref))
		btn_row.add_child(copy_btn)

		var del_btn := Button.new()
		del_btn.text = "🗑 Elimina"
		del_btn.flat = true
		var idx := i
		del_btn.pressed.connect(func(): _delete_snippet(idx))
		btn_row.add_child(del_btn)

		snippets_list.add_child(card)

func _delete_snippet(index: int) -> void:
	if index < snippets_data.size():
		snippets_data.remove_at(index)
		_save_snippets()
		_refresh_snippets_ui()

func _load_snippets() -> void:
	if not FileAccess.file_exists(SNIPPETS_FILE): return
	var file := FileAccess.open(SNIPPETS_FILE, FileAccess.READ)
	if file == null: return
	var json := JSON.new()
	if json.parse(file.get_as_text()) == OK:
		snippets_data = json.get_data()
	file.close()
	_refresh_snippets_ui()

func _save_snippets() -> void:
	var file := FileAccess.open(SNIPPETS_FILE, FileAccess.WRITE)
	if file == null: return
	file.store_string(JSON.stringify(snippets_data, "\t"))
	file.close()

# ─────────────────────────────────────────────────────────────
#  Cronologia persistente
# ─────────────────────────────────────────────────────────────
func _load_history() -> void:
	if not FileAccess.file_exists(HISTORY_FILE):
		_add_message("Sistema", "👁 Ciao! Sono Godo4NewbiAI.\n\n💬 Chiedimi qualsiasi cosa su Godot 4\n📖 Usa il pulsante per condividere lo script aperto\n🐛 Incolla errori con il pulsante bug\n▶ Eseguo EditorScript direttamente nell'editor", COLOR_SYSTEM)
		return

	var file := FileAccess.open(HISTORY_FILE, FileAccess.READ)
	if file == null: return
	var json := JSON.new()
	if json.parse(file.get_as_text()) == OK:
		conversation_history = json.get_data()
	file.close()

	var count := conversation_history.size()
	_add_message("Sistema", "👁 Bentornato! Ho caricato %d messaggi dalla sessione precedente.\nUsa 🗑 per ricominciare da zero." % count, COLOR_SYSTEM)

func _save_history() -> void:
	# Tieni solo gli ultimi MAX_HISTORY messaggi
	if conversation_history.size() > MAX_HISTORY:
		conversation_history = conversation_history.slice(conversation_history.size() - MAX_HISTORY)

	var file := FileAccess.open(HISTORY_FILE, FileAccess.WRITE)
	if file == null: return
	file.store_string(JSON.stringify(conversation_history, "\t"))
	file.close()

# ─────────────────────────────────────────────────────────────
#  Messaggi semplici (sistema, errori, utente)
# ─────────────────────────────────────────────────────────────
func _add_message(sender: String, text: String, color: Color) -> void:
	var bubble := PanelContainer.new()
	var vbox   := VBoxContainer.new()
	bubble.add_child(vbox)

	var sl := Label.new()
	sl.text = sender
	sl.add_theme_color_override("font_color", color)
	sl.add_theme_font_size_override("font_size", 11)
	vbox.add_child(sl)

	var te := _make_selectable_text(text)
	vbox.add_child(te)

	messages_box.add_child(bubble)
	await get_tree().process_frame
	scroll_container.scroll_vertical = scroll_container.get_v_scroll_bar().max_value

func _clear_conversation() -> void:
	conversation_history.clear()
	_save_history()
	script_label.visible = false
	for child in messages_box.get_children():
		child.queue_free()
	_add_message("Sistema", "🔄 Conversazione azzerata.", COLOR_SYSTEM)
