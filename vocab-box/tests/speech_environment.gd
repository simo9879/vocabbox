extends SceneTree

const SpeechEnvironment = preload("res://scripts/speech_environment.gd")

var failures := 0

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var path := "user://speech-environment-fixture.env"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("# Fixture only\nexport ELEVENLABS_API_KEY=fixture-key\nAI_API_KEY='fixture-deepseek-key'\n")
	file.close()
	check(SpeechEnvironment.read_file(path, "ELEVENLABS_API_KEY") == "fixture-key", "Reads a key from a dotenv export")
	check(SpeechEnvironment.read_file(path, "AI_API_KEY") == "fixture-deepseek-key", "Reads the quoted DeepSeek key")
	check(SpeechEnvironment.read_file(path, "MISSING") == "", "Missing values stay empty")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	# If this checkout has a local key, verify the loader reaches its root .env without exposing it.
	var root_env := ProjectSettings.globalize_path("res://").path_join("..").path_join(".env").simplify_path()
	var local_key := SpeechEnvironment.read_file(root_env, "ELEVENLABS_API_KEY")
	if not local_key.is_empty() and OS.get_environment("ELEVENLABS_API_KEY").is_empty():
		check(SpeechEnvironment.get_value("ELEVENLABS_API_KEY") == local_key, "Game resolves the root dotenv key")
	OS.set_environment("VOCAB_SPEECH_ENV_TEST", "from-process")
	check(SpeechEnvironment.get_value("VOCAB_SPEECH_ENV_TEST") == "from-process", "Process environment takes precedence")
	OS.unset_environment("VOCAB_SPEECH_ENV_TEST")
	print("Speech environment: ", failures, " failures")
	quit(0 if failures == 0 else 1)

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
