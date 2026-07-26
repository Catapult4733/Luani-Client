# client_and_studio/scripts/protocol_parser.gd
extends Node

## Handles custom URI protocol parsing for Luani (luani://join?server=IP:PORT&auth=TOKEN)

signal protocol_received(session_data: Dictionary)

var latest_session_data: Dictionary = {
	"valid": false,
	"action": "",
	"server_ip": "",
	"server_port": 0,
	"auth_token": "",
	"raw_uri": ""
}

func _ready() -> void:
	# Parse command line arguments on startup
	var args := OS.get_cmdline_args()
	args.append_array(OS.get_cmdline_user_args())
	
	var uri_found := ""
	for arg in args:
		var clean_arg: String = arg.strip_edges().trim_prefix("'").trim_suffix("'").trim_prefix("\"").trim_suffix("\"").strip_edges()
		if clean_arg.begins_with("luani://") or "luani://join" in clean_arg:
			uri_found = clean_arg
			break
		elif clean_arg.begins_with("--uri="):
			var sub_uri := clean_arg.trim_prefix("--uri=").strip_edges().trim_prefix("'").trim_suffix("'").trim_prefix("\"").trim_suffix("\"").strip_edges()
			uri_found = sub_uri
			break
			
	if uri_found != "":
		latest_session_data = parse_uri(uri_found)
		if latest_session_data.get("valid", false):
			print("[Luani ProtocolParser] Successfully parsed URI data: ", latest_session_data)
			call_deferred("emit_signal", "protocol_received", latest_session_data)
		else:
			push_error("[Luani ProtocolParser] Failed to parse URI: " + uri_found)

## Parses a luani:// URI into a Dictionary containing server details and auth token
func parse_uri(uri_string: String) -> Dictionary:
	var clean_uri := uri_string.strip_edges().trim_prefix("'").trim_suffix("'").trim_prefix("\"").trim_suffix("\"").strip_edges()
	print("[Luani ProtocolParser] Cleaned launch URI: ", clean_uri)

	var result := {
		"valid": false,
		"action": "",
		"server_ip": "127.0.0.1",
		"server_port": 7777,
		"auth_token": "",
		"raw_uri": clean_uri
	}
	
	if not clean_uri.begins_with("luani://"):
		return result

	# Strip scheme prefix
	var path_and_query := clean_uri.trim_prefix("luani://")
	
	# Separate action (e.g. 'join') and query parameters ('?server=IP:PORT&auth=TOKEN')
	var action := ""
	var query_string := ""
	
	if "?" in path_and_query:
		var parts := path_and_query.split("?", true, 1)
		action = parts[0].strip_edges()
		query_string = parts[1].strip_edges()
	else:
		action = path_and_query.strip_edges()
		
	result["action"] = action
	
	# Parse query parameters
	if query_string != "":
		var params := query_string.split("&")
		for param in params:
			var kv := param.split("=", true, 1)
			if kv.size() == 2:
				var key := kv[0].strip_edges().to_lower()
				var value := kv[1].strip_edges()
				
				if key == "server":
					if ":" in value:
						var host_port := value.split(":", true, 1)
						result["server_ip"] = host_port[0]
						result["server_port"] = host_port[1].to_int()
					else:
						result["server_ip"] = value
				elif key == "auth" or key == "token":
					result["auth_token"] = value
				elif key == "username" or key == "user":
					result["username"] = value.uri_decode()
				elif key == "avatar":
					result["avatar"] = value.uri_decode()
					
	# Validation rule: 'join' action requires valid IP/domain and non-zero port
	if action == "join" or action == "":
		result["action"] = "join"
		if result["server_ip"] != "" and result["server_port"] > 0:
			result["valid"] = true
			
	return result
