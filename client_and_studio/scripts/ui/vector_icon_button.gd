# client_and_studio/scripts/ui/vector_icon_button.gd
extends Button

## Custom Vector-Drawn Topbar Icon Button for Menu, Chat, and Microphone UI

enum IconType { MENU, CHAT, MIC }

@export var icon_type: IconType = IconType.MENU
@export var is_muted: bool = false

func _ready() -> void:
	custom_minimum_size = Vector2(40, 40)
	flat = false
	
	# Apply website styled rounded button style
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.11, 0.18, 0.88)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.2, 0.28, 0.45, 0.6)
	style.corner_radius_top_left = 20
	style.corner_radius_top_right = 20
	style.corner_radius_bottom_right = 20
	style.corner_radius_bottom_left = 20
	
	var hover_style := style.duplicate() as StyleBoxFlat
	hover_style.bg_color = Color(0.14, 0.19, 0.3, 0.95)
	hover_style.border_color = Color(0.55, 0.36, 0.96, 0.8)
	
	var press_style := style.duplicate() as StyleBoxFlat
	press_style.bg_color = Color(0.05, 0.07, 0.12, 0.95)
	
	add_theme_stylebox_override("normal", style)
	add_theme_stylebox_override("hover", hover_style)
	add_theme_stylebox_override("pressed", press_style)

func set_muted(muted: bool) -> void:
	is_muted = muted
	queue_redraw()

var galaxy_texture: Texture2D = null

func _draw() -> void:
	var center := size * 0.5
	var color := Color(0.92, 0.95, 1.0)
	
	match icon_type:
		IconType.MENU:
			var tex: Texture2D = null
			if ResourceLoader.exists("res://icon.png"):
				tex = load("res://icon.png") as Texture2D
			if not tex and ResourceLoader.exists("res://icon.svg"):
				tex = load("res://icon.svg") as Texture2D
				
			if tex:
				var rect := Rect2(center.x - 12.0, center.y - 12.0, 24.0, 24.0)
				draw_texture_rect(tex, rect, false)
			else:
				# Vector Luani Galaxy Spiral Logo
				draw_circle(center, 9.0, Color(0.08, 0.05, 0.18))
				var galaxy_purple := Color(0.55, 0.36, 0.96)
				var galaxy_cyan := Color(0.2, 0.75, 0.95)
				for i in range(12):
					var angle := deg_to_rad(i * 30.0)
					var radius := 2.0 + (i * 0.6)
					var pos := center + Vector2(cos(angle), sin(angle)) * radius
					var col := galaxy_purple.lerp(galaxy_cyan, float(i) / 12.0)
					draw_circle(pos, 1.8, col)
				draw_circle(center, 3.0, Color(1, 1, 1, 0.9))
				
		IconType.CHAT:
			# Draw 2D Vector Speech Bubble
			var rect := Rect2(center.x - 9.0, center.y - 8.0, 18.0, 13.0)
			draw_rect(rect, color, false, 2.0)
			# Bubble tail
			var tail_points := PackedVector2Array([
				Vector2(center.x - 5.0, center.y + 5.0),
				Vector2(center.x - 9.0, center.y + 9.0),
				Vector2(center.x - 1.0, center.y + 5.0)
			])
			draw_colored_polygon(tail_points, color)
			# 3 dots
			for i in range(3):
				draw_circle(Vector2(center.x - 4.0 + (i * 4.0), center.y - 1.5), 1.0, Color(0.1, 0.14, 0.22))
				
		IconType.MIC:
			# Draw Microphone Capsule & Stand
			var cap_rect := Rect2(center.x - 3.5, center.y - 8.0, 7.0, 10.0)
			draw_rect(cap_rect, color, false, 2.0)
			
			# Stand U-curve
			var u_rect := Rect2(center.x - 6.5, center.y - 3.0, 13.0, 8.0)
			draw_arc(center + Vector2(0, 1.0), 6.0, deg_to_rad(0), deg_to_rad(180), 16, color, 2.0)
			# Vertical stem & base line
			draw_line(Vector2(center.x, center.y + 7.0), Vector2(center.x, center.y + 10.0), color, 2.0)
			draw_line(Vector2(center.x - 5.0, center.y + 10.0), Vector2(center.x + 5.0, center.y + 10.0), color, 2.0)
			
			if is_muted:
				# Sharp Red Cross / Strike-through Slash Line
				var red_color := Color(0.95, 0.25, 0.25)
				draw_line(Vector2(center.x - 9.0, center.y + 9.0), Vector2(center.x + 9.0, center.y - 9.0), red_color, 3.0)
				draw_line(Vector2(center.x - 9.0, center.y - 9.0), Vector2(center.x + 9.0, center.y + 9.0), red_color, 3.0)
