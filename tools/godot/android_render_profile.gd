extends Node
## NON-SHIPPING offline render benchmark. No backend, credentials, admissions or online claims.
const World = preload("res://scripts/world.gd")
const MobileUI = preload("res://scripts/mobile_ui.gd")
var _elapsed := 0.0
var _warm_frames := 0
var _frames: Array[float] = []
var _draws: Array[float] = []
var _primitives: Array[float] = []
var _process_times: Array[float] = []
var _sample_seconds := 0.0
var _finished := false
var _started_usec: int
var _last_usec: int
func _ready() -> void:
	MobileUI.configure(get_window())
	SessionState.online=false
	SessionState.set_identity({"username":"Render QA","avatar":{}})
	var world := World.new(); add_child(world)
	_started_usec=Time.get_ticks_usec();_last_usec=_started_usec
	print("LUANI_RENDER_QA_START "+JSON.stringify({"android":OS.has_feature("android"),"viewport":str(get_viewport().get_visible_rect().size),"engine":Engine.get_version_info().string,"main_scene":"offline render fixture"}))
func _process(_delta: float) -> void:
	if _finished: return
	var now:=Time.get_ticks_usec()
	var delta:=float(now-_last_usec)/1000000.0;_last_usec=now
	_elapsed=float(now-_started_usec)/1000000.0
	if _elapsed<8.0 or _warm_frames<12:
		_warm_frames+=1;return
	_sample_seconds+=delta;_frames.append(delta*1000.0)
	_draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	_primitives.append(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	_process_times.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000.0)
	if _sample_seconds>=12.0 and _frames.size()>=30 or _elapsed>=45.0:
		_finished=true
		_frames.sort()
		var result := {"android":OS.has_feature("android"),"samples":_frames.size(),"seconds":_sample_seconds,"mean_fps":float(_frames.size())/_sample_seconds,"frame_ms_p50":_percentile(_frames,0.5),"frame_ms_p95":_percentile(_frames,0.95),"mean_draw_calls":_mean(_draws),"mean_primitives":_mean(_primitives),"mean_process_ms":_mean(_process_times),"configured_fps_cap":Engine.max_fps,"timing_source":"monotonic wall clock, not clamped game delta","live_network_used":false,"scenario":"stationary spawn;18 pickups;5 targets;one offline avatar"}
		print("LUANI_RENDER_QA_RESULT "+JSON.stringify(result))
		get_tree().quit()
func _percentile(values: Array[float],p: float) -> float:
	return values[clampi(int(float(values.size()-1)*p),0,values.size()-1)]
func _mean(values: Array[float]) -> float:
	var total:=0.0
	for value in values:total+=value
	return total/float(values.size())
