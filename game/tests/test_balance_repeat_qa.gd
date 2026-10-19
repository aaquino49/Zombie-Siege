extends TestCase
## T-203: cadence jitter must not perturb a run with no bot decisions.

var output_dir: String

func before_each() -> void:
	output_dir = ProjectSettings.globalize_path(temp_path("balance_repeat_qa"))

func after_each() -> void:
	for filename: String in ["none_42_r1.csv", "none_42_r2.csv", "none_42_r3.csv", "summary.csv"]:
		remove_test_temp_file(output_dir.path_join(filename))
	if DirAccess.dir_exists_absolute(output_dir):
		assert_eq(DirAccess.remove_absolute(output_dir), OK)

func test_repeat_cli_jitters_decisions_without_changing_no_bot_simulation() -> void:
	var executable: String = OS.get_executable_path()
	var console: String = executable.get_basename() + "_console.exe"
	if FileAccess.file_exists(console):
		executable = console
	var output: Array = []
	var args := PackedStringArray(["--headless", "--path", ProjectSettings.globalize_path("res://"),
		"--script", "res://dev/balance_run.gd", "--", "--repeat=3", "--nights=8",
		"--seeds=42", "--strategy=none", "--difficulty=hard", "--out=" + output_dir])
	assert_eq(OS.execute(executable, args, output, true), 0, str(output))
	var stdout: String = "".join(output)
	assert_eq(stdout.count("BALANCE seed=42 strategy=none"), 3)
	assert_true(stdout.contains("BALANCE_SEED_RATE difficulty=hard seed=42 strategy=none repeats=3"))
	assert_true(stdout.contains("BALANCE_SUMMARY difficulty=hard strategy=none runs=3"))
	var first: String = output_dir.path_join("none_42_r1.csv")
	var second: String = output_dir.path_join("none_42_r2.csv")
	assert_true(FileAccess.file_exists(first) and FileAccess.file_exists(second))
	if not FileAccess.file_exists(first) or not FileAccess.file_exists(second):
		return
	assert_true(FileAccess.get_file_as_string(first) == FileAccess.get_file_as_string(second),
		"With strategy=none there are no bot decisions to jitter; repeat CSVs must match. Keep the simulation timestep fixed.")
	assert_eq(FileAccess.get_file_as_string(first), FileAccess.get_file_as_string(output_dir.path_join("none_42_r3.csv")))
	var lines: PackedStringArray = FileAccess.get_file_as_string(first).strip_edges().split("\n")
	assert_eq(lines[0], ",".join(BalanceBot.COLUMNS))
	assert_eq(lines[-1].split(",")[BalanceBot.COLUMNS.find("end")], "loss")
