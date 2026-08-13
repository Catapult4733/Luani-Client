# client_and_studio/scripts/ui/vector_icon_button.gd
extends Button

## Custom Vector-Drawn Topbar Icon Button for Menu, Chat, and Microphone UI

enum IconType { MENU, CHAT, MIC }

@export var icon_type: IconType = IconType.MENU
@export var is_muted: bool = false

func _ready() -> void:
	text = ""
	icon = null
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
			# Vector Luani Galaxy Spiral Logo (No white Godot icon!)
			draw_circle(center, 9.5, Color(0.06, 0.08, 0.14, 0.95))
			
			var purple_color := Color(0.65, 0.35, 0.98) # #a855f7
			var cyan_color := Color(0.02, 0.71, 0.83)   # #06b6d4
			
			# Dual Spiral Arms
			for i in range(16):
				var progress := float(i) / 16.0
				var angle1 := progress * TAU * 1.2
				var angle2 := angle1 + PI
				var dist := 2.5 + (progress * 7.0)
				var star_color := purple_color.lerp(cyan_color, progress)
				
				# Arm 1
				var pos1 := center + Vector2(cos(angle1), sin(angle1)) * dist
				draw_circle(pos1, 1.5, star_color)
				
				# Arm 2
				var pos2 := center + Vector2(cos(angle2), sin(angle2)) * dist
				draw_circle(pos2, 1.5, star_color)
				
			# Core glowing galaxy center
			draw_circle(center, 3.8, Color(0.55, 0.36, 0.96, 0.7))
			draw_circle(center, 2.0, Color(0.95, 0.98, 1.0, 1.0))
				
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
