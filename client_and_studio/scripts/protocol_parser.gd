# client_and_studio/scripts/protocol_parser.gd
class_name ProtocolParser
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
		if arg.begins_with("luani://"):
			uri_found = arg
			break
		elif arg.begins_with("--uri="):
			uri_found = arg.trim_prefix("--uri=")
			break
			
	if uri_found != "":
		print("[Luani ProtocolParser] Found protocol URI in arguments: ", uri_found)
		latest_session_data = parse_uri(uri_found)
		if latest_session_data.get("valid", false):
			print("[Luani ProtocolParser] Successfully parsed URI data: ", latest_session_data)
			call_deferred("emit_signal", "protocol_received", latest_session_data)
		else:
			push_error("[Luani ProtocolParser] Failed to parse URI: " + uri_found)

## Parses a luani:// URI into a Dictionary containing server details and auth token
func parse_uri(uri_string: String) -> Dictionary:
	var result := {
		"valid": false,
		"action": "",
		"server_ip": "127.0.0.1",
		"server_port": 7777,
		"auth_token": "",
		"raw_uri": uri_string
	}
	
	if not uri_string.begins_with("luani://"):
		return result

	# Strip scheme prefix
	var path_and_query := uri_string.trim_prefix("luani://")
	
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
					
	# Validation rule: 'join' action requires valid IP and non-zero port
	if action == "join" or action == "":
		result["action"] = "join"
		if result["server_ip"] != "" and result["server_port"] > 0:
			result["valid"] = true
			
	return result
