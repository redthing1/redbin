module rdb.app;

import std.stdio;

import std.stdio;
import std.conv;
import std.file;
import std.path;
import std.algorithm : min;

import commandr;
import typetips;
import minlog;

import rdb.analysis;
import rdb.util;

enum APP_NAME = "redbin";
enum APP_DESC = "opaque binary analysis utilities";
enum APP_VERSION = "v0.1.x";

enum CMD_ENTROPY = "entropy";

void main(string[] args) {
	// dfmt off
	auto a = new Program(APP_NAME, APP_VERSION)
		.summary(APP_DESC)
		.add(new Flag("v", "verbose", "turns on more verbose output"))
        .add(new Command(CMD_ENTROPY, "calculate entropy")
			.add(new Argument("file", "file to calculate entropy for"))
			.add(new Option("s", "slide", "window slide").name("window_slide").defaultValue("1"))
			.add(new Option("w", "window", "window size").name("window_size").defaultValue("1024"))
			.add(new Flag(null, "graph", "output entropy graph"))
			.add(new Flag(null, "c", "entropy graph columns"))
			.add(new Flag(null, "r", "entropy graph rows"))
			.add(new Option(null, "csv", "output entropy csv"))
		)
		.parse(args);
		
	// dfmt on

	// set up logger
	logger.use_colors = true;
	logger.meta_timestamp = false;
	logger.source = "redbin";
	logger.verbosity = (Verbosity.info.to!int
			+ min(a.occurencesOf("verbose"), 2)
			- min(a.occurencesOf("quiet"), 2)
	)
		.to!Verbosity;

	// dfmt off
	a
        .on(CMD_ENTROPY, (args) {
            cmd_entropy(args);
        })
        ;
	// dfmt on
}

void cmd_entropy(ProgramArgs args) {
	auto in_file = args.arg("file");
	auto window_slide = args.option("window_slide").to!size_t;
	auto window_size = args.option("window_size").to!size_t;

	auto enable_graph = args.flag("graph");
	auto graph_columns = args.option("c");
	auto graph_rows = args.option("r");
	auto save_csv = args.option("csv");

	auto in_file_size = std.file.getSize(in_file);
	auto in_file_name = std.path.baseName(in_file);
	logger.info("reading file: [%s] (%s)", in_file, human_file_size(in_file_size));
	auto in_file_data = cast(ubyte[]) std.file.read(in_file);

	auto analyzer = new EntropyAnalyzer(
		in_file_data,
		window_size,
		window_slide
	);
	logger.info("running analysis");
	analyzer.analyze();

	logger.info("entropy analysis: [%s]", in_file_name);
	logger.info("  window: size=%s, slide=%s", window_size, window_slide);
	logger.info("  window entropy: min=%.3f, max=%.3f, avg=%.3f, med=%.3f, std=%.3f",
		analyzer.window_entropy_ratio_min,
		analyzer.window_entropy_ratio_max,
		analyzer.window_entropy_ratio_mean,
		analyzer.window_entropy_ratio_median,
		analyzer.window_entropy_ratio_std,	
	);
	
	logger.info("  file entropy: %.3f",
		analyzer.aggregate_entropy_ratio
	);
	logger.info("  file mean: %.3f", analyzer.aggregate_mean);
}
