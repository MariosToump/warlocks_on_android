class_name RoundHud
extends Control
## Round/match HUD, built in code: scoreboard (top-left), round banners
## (centre), kill feed (top-right) and the match-over screen.
## `game` is set by game.gd, which emits the signals this listens to.

signal play_again_pressed
signal menu_pressed

const TEAM_COLORS := {
	Wizard.TeamColor.RED: Color(1.0, 0.42, 0.32),
	Wizard.TeamColor.BLUE: Color(0.45, 0.65, 1.0),
	Wizard.TeamColor.GREEN: Color(0.45, 0.9, 0.45),
	Wizard.TeamColor.PURPLE: Color(0.82, 0.55, 1.0),
}
const FEED_LIFE := 4.0

var game: Node:
	set(v):
		game = v
		_connect()

var _board: Scoreboard
var _banner: Label
var _sub: Label
var _feed: VBoxContainer
var _match_panel: PanelContainer
var _match_title: Label
var _standings: Label
var _play_again: Button
var _banner_tween: Tween


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_board = Scoreboard.new()
	_board.hud = self
	_board.position = Vector2(12, 12)
	add_child(_board)

	_banner = _label(52)
	_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_banner.offset_left = -500
	_banner.offset_right = 500
	_banner.offset_top = -270
	_banner.offset_bottom = -200
	_sub = _label(26)
	_sub.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_sub.offset_left = -500
	_sub.offset_right = 500
	_sub.offset_top = -198
	_sub.offset_bottom = -160

	_feed = VBoxContainer.new()
	_feed.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_feed.alignment = BoxContainer.ALIGNMENT_BEGIN
	add_child(_feed)
	_feed.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_feed.offset_left = -330
	_feed.offset_right = -12
	_feed.offset_top = 12 + Minimap.DIAMETER + 8 # below the minimap
	_feed.grow_horizontal = Control.GROW_DIRECTION_BEGIN

	_build_match_panel()


func _label(font_size: int) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", maxi(floori(font_size / 6.0), 4))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


func _build_match_panel() -> void:
	_match_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.05, 0.05, 0.88)
	sb.border_color = Color(1.0, 0.45, 0.15)
	sb.set_border_width_all(3)
	sb.set_content_margin_all(24)
	_match_panel.add_theme_stylebox_override("panel", sb)
	add_child(_match_panel)
	_match_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_match_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_match_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	_match_panel.add_child(box)
	_match_title = Label.new()
	_match_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_match_title.add_theme_font_size_override("font_size", 40)
	_match_title.add_theme_color_override("font_outline_color", Color.BLACK)
	_match_title.add_theme_constant_override("outline_size", 6)
	box.add_child(_match_title)
	_standings = Label.new()
	_standings.add_theme_font_size_override("font_size", 22)
	_standings.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_standings)
	_play_again = Button.new()
	_play_again.text = "Play again"
	_play_again.add_theme_font_size_override("font_size", 26)
	_play_again.custom_minimum_size = Vector2(240, 56)
	_play_again.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_play_again.pressed.connect(_on_play_again)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 16)
	box.add_child(buttons)
	buttons.add_child(_play_again)
	var menu := Button.new()
	menu.text = "Menu"
	menu.add_theme_font_size_override("font_size", 26)
	menu.custom_minimum_size = Vector2(180, 56)
	menu.pressed.connect(func():
		Sfx.play("click")
		_match_panel.visible = false
		menu_pressed.emit())
	buttons.add_child(menu)
	_match_panel.visible = false


func _connect() -> void:
	game.round_started.connect(_on_round_started)
	game.fight_started.connect(_on_fight_started)
	game.round_ended.connect(_on_round_ended)
	game.match_ended.connect(_on_match_ended)
	game.kill_scored.connect(_on_kill)


func color_of(w: Wizard) -> Color:
	return TEAM_COLORS[w.team_color]


func _process(_delta: float) -> void:
	if game == null:
		return
	if game.state == game.State.COUNTDOWN:
		_sub.text = str(ceili(game.state_left))
		if game.shop_skipped:
			_sub.text = "No gold to spend: no shop this time   " + _sub.text
	_board.queue_redraw()


func _show_banner(text: String, col := Color.WHITE, sub := "") -> void:
	if _banner_tween:
		_banner_tween.kill()
	_banner.text = text
	_banner.modulate = col
	_sub.text = sub
	_sub.modulate = Color.WHITE


func _on_round_started(n: int) -> void:
	_match_panel.visible = false
	_show_banner("Round %d" % n, Color.WHITE, str(ceili(game.countdown_time)))


func _on_fight_started() -> void:
	_show_banner("Burn!", Color(1.0, 0.6, 0.2))
	_banner_tween = create_tween()
	_banner_tween.tween_interval(0.5)
	_banner_tween.tween_property(_banner, "modulate:a", 0.0, 0.5)


func _on_round_ended(winner: Wizard) -> void:
	if winner == null:
		_show_banner("Draw!", Color(0.9, 0.9, 0.9), "No point this round")
		return
	var who: String = game.display_name(winner)
	var text := "You win the round!" if winner == game.player else "%s wins the round!" % who
	var sub := ""
	if game.match_winner == null:
		sub = "%d / %d" % [game.wins[winner], game.wins_to_take_match]
	_show_banner(text, color_of(winner), sub)


func _on_match_ended(winner: Wizard) -> void:
	_show_banner("")
	var title := "You win the match!" if winner == game.player \
			else "%s wins the match" % game.display_name(winner)
	_match_title.text = title
	_match_title.modulate = color_of(winner)
	var order: Array = game.all_wizards.duplicate()
	order.sort_custom(func(a, b):
		if game.wins[a] != game.wins[b]:
			return game.wins[a] > game.wins[b]
		return game.kills[a] > game.kills[b])
	var lines := PackedStringArray()
	for i in order.size():
		var w: Wizard = order[i]
		var nw: int = game.wins[w]
		var nk: int = game.kills[w]
		lines.append("%d.  %-7s  %d %s   %d %s" % [i + 1, game.display_name(w),
				nw, "win" if nw == 1 else "wins", nk, "kill" if nk == 1 else "kills"])
	_standings.text = "\n".join(lines)
	_match_panel.visible = true
	_play_again.grab_focus()


func _on_play_again() -> void:
	Sfx.play("click")
	_match_panel.visible = false
	play_again_pressed.emit()


func _on_kill(killer: Wizard, victim: Wizard) -> void:
	var l := RichTextLabel.new()
	l.bbcode_enabled = true
	l.fit_content = true
	l.scroll_active = false
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.custom_minimum_size = Vector2(318, 0)
	l.add_theme_font_size_override("normal_font_size", 18)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 5)
	l.text = "[right][color=#%s]%s[/color] took out [color=#%s]%s[/color][/right]" % [
		color_of(killer).to_html(false), game.display_name(killer),
		color_of(victim).to_html(false), game.display_name(victim)]
	_feed.add_child(l)
	var t := l.create_tween()
	t.tween_interval(FEED_LIFE)
	t.tween_property(l, "modulate:a", 0.0, 0.5)
	t.tween_callback(l.queue_free)


## Top-left: one row per wizard — colour swatch, name, health bar,
## round-win pips, kills; then a line with your knockback bonus.
class Scoreboard:
	extends Control

	const ROW_H := 22
	const PIPS_X := 150

	var hud: RoundHud

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var game = hud.game
		if game == null:
			return
		var font := ThemeDB.fallback_font
		var n: int = game.all_wizards.size()
		var need: int = game.wins_to_take_match
		var kills_x := PIPS_X + need * 14 + 6
		var w_total := kills_x + 52
		size = Vector2(w_total, n * ROW_H + 10 + ROW_H)
		draw_rect(Rect2(0, 0, w_total, n * ROW_H + 10), Color(0, 0, 0, 0.45))
		for i in n:
			var w: Wizard = game.all_wizards[i]
			var y := 5 + i * ROW_H
			var dim := 1.0 if w.alive or game.state != game.State.FIGHT else 0.4
			var col: Color = hud.color_of(w)
			col.a = dim
			draw_rect(Rect2(8, y + 5, 10, 10), col)
			var text_col := Color(1, 1, 1, dim)
			draw_string(font, Vector2(24, y + 16), game.display_name(w), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, text_col)
			# Health bar (0 when dead).
			var hp := clampf(w.health / w.max_health, 0.0, 1.0) if w.alive else 0.0
			var bar := Rect2(88, y + 7, 52, 7)
			draw_rect(bar, Color(0, 0, 0, 0.6 * dim))
			var hp_col := Color(0.35, 0.85, 0.35) if hp > 0.5 else (Color(0.95, 0.75, 0.2) if hp > 0.25 else Color(0.95, 0.3, 0.2))
			hp_col.a = dim
			draw_rect(Rect2(bar.position, Vector2(bar.size.x * hp, bar.size.y)), hp_col)
			for p in need:
				var r := Rect2(PIPS_X + p * 14, y + 6, 9, 9)
				if p < game.wins[w]:
					draw_rect(r, Color(1.0, 0.75, 0.2, dim))
				else:
					draw_rect(r, Color(1, 1, 1, 0.35 * dim), false, 1.0)
			draw_string(font, Vector2(kills_x, y + 16), "%d K" % game.kills[w], HORIZONTAL_ALIGNMENT_RIGHT, 46, 16, text_col)
		# Your knockback bonus: damage taken makes you fly further.
		var me: Wizard = game.player
		var kb := roundi(me.damage_taken * me.knockback_per_damage * 100.0)
		if me.alive and kb > 0:
			var kb_col := Color(1, 0.8, 0.4) if kb < 50 else Color(1, 0.45, 0.3)
			draw_string(font, Vector2(8, n * ROW_H + 10 + 17), "Knockback +%d%%" % kb,
					HORIZONTAL_ALIGNMENT_LEFT, -1, 16, kb_col)
