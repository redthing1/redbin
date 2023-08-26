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
			.add(new Option("c", "cols", "entropy graph columns").defaultValue("80"))
			.add(new Option("r", "rows", "entropy graph rows").defaultValue("20"))
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
	auto graph_columns = args.option("cols").to!size_t;
	auto graph_rows = args.option("rows").to!size_t;
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

	if (enable_graph) {
		// v1: just implement a simple graph
		auto window_entropy_ratios = analyzer.window_entropy_ratio_map;
		// size_t[size_t] graph_columns_map;
		size_t[] graph_column_data;
		graph_column_data.length = graph_columns;

		import std.math : round;

		// downsample to column count
		// scale height to row count
		auto sample_every_ith = cast(size_t)(
			window_entropy_ratios.keys.length / graph_columns.to!float);

		// foreach (i, window_pos; window_entropy_ratios.keys) {
		// 	if (i % sample_every_ith != 0) {
		// 		continue;
		// 	}
		// 	if (i >= graph_columns) {
		// 		break;
		// 	}
		// 	auto sample_i = i / sample_every_ith;
		// 	// writefln("  graph: sample #%s from window@%s", sample_i, window_pos);
		// 	auto v = window_entropy_ratios[window_pos];
		// 	// auto height = cast(size_t)(v * graph_rows.to!float);
		// 	import std.math: round;
		// 	auto height = cast(size_t)(round(v * graph_rows.to!float));
		// 	graph_column_data[sample_i] = height;
		// }

		// average data into bins
		auto bin_size = cast(size_t)(window_entropy_ratios.keys.length / graph_columns.to!float);
		if (bin_size == 0) {
			bin_size = 1;
		}

		foreach (i, window_pos; window_entropy_ratios.keys) {
			auto bin_i = i / bin_size;
			if (bin_i >= graph_columns) {
				break;
			}
			// writefln("  graph: bin #%s from window@%s", bin_i, window_pos);
			auto w_entropy_ratio = window_entropy_ratios[window_pos];
			auto row_scaled_entropy_ratio = w_entropy_ratio * graph_rows.to!float;
			// writefln("    entropy ratio: %.3f", w_entropy_ratio);
			// writefln("    row scaled entropy ratio: %.3f", row_scaled_entropy_ratio);
			auto height = cast(size_t)(round(row_scaled_entropy_ratio));
			graph_column_data[bin_i] += height;
		}

		// normalize all bins
		foreach (i, height; graph_column_data) {
			auto normalized_height = height / bin_size.to!float;
			// writefln("  graph: bin #%s normalized %s -> %s", i, height, normalized_height);
			graph_column_data[i] = cast(size_t)(round(height / bin_size.to!float));
		}

		// print graph
		logger.info("  graph: %s x %s", graph_columns, graph_rows);
		// writefln("  graph columns map: %s", graph_column_data);
		for (size_t i = 0; i < graph_rows; i++) {
			for (size_t j = 0; j < graph_columns; j++) {
				auto height = graph_column_data[j];
				if (height >= graph_rows - i) {
					write("#");
				} else {
					write(" ");
				}
			}
			writeln();
		}
	}
}
