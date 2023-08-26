module rdb.analysis.entropy_analyzer;

import std.math;

import rdb.analysis.analyzer;
import mir.ndslice.iterator;
import rdb.util;

class EntropyAnalyzer : IBinaryAnalyzer {
    ubyte[] data;
    size_t window_size;
    size_t window_slide;

    this(ubyte[] data, size_t window_size = 1024, size_t window_slide = 1) {
        this.data = data;
        this.window_size = window_size;
        this.window_slide = window_slide;
    }

    double theoretical_max_shantropy(size_t length) {
        return log2(cast(double) length);
    }

    double buffer_shantropy(ubyte[] buffer) {
        double entropy = 0;
        size_t[] counts = new size_t[256];
        foreach (ubyte b; buffer) {
            counts[b]++;
        }
        foreach (size_t count; counts) {
            if (count > 0) {
                double p = cast(double) count / buffer.length;
                entropy -= p * log2(p);
            }
        }
        return entropy;
    }

    double buffer_shantropy_ratio(ubyte[] buffer) {
        return buffer_shantropy(buffer) / theoretical_max_shantropy(buffer.length);
    }

    double buffer_mean(ubyte[] buffer) {
        double mean = 0;
        foreach (ubyte b; buffer) {
            mean += b;
        }
        mean = (mean / buffer.length) / 255;
        return mean;
    }

    double[size_t] window_entropy_ratio_map;
    double[size_t] window_mean_map;
    double aggregate_entropy_bits;
    double aggregate_entropy_ratio;
    double aggregate_mean;
    double theoretical_max_entropy;
    double window_theoretical_max_entropy;
    double window_entropy_ratio_min;
    double window_entropy_ratio_max;
    double window_entropy_ratio_mean;
    double window_entropy_ratio_median;
    double window_entropy_ratio_std;

    void analyze() {
        // calculate aggregate stats
        theoretical_max_entropy = theoretical_max_shantropy(data.length);
        aggregate_entropy_bits = buffer_shantropy(data);
        aggregate_entropy_ratio = aggregate_entropy_bits / theoretical_max_entropy;
        aggregate_mean = buffer_mean(data);

        window_theoretical_max_entropy = theoretical_max_shantropy(window_size);

        // calculate stats for each window
        for (size_t i = 0; i < data.length - window_size; i += window_slide) {
            // slice for window starting at i
            auto buffer_slice = data[i .. i + window_size];

            auto window_entropy = buffer_shantropy_ratio(buffer_slice);
            window_entropy_ratio_map[i] = window_entropy;

            auto window_mean = buffer_mean(buffer_slice);
            window_mean_map[i] = window_mean;
        }

        auto window_entropy_ratio_stats = five_point_summary(window_entropy_ratio_map.values);
        window_entropy_ratio_min = window_entropy_ratio_stats[0];
        window_entropy_ratio_max = window_entropy_ratio_stats[1];
        window_entropy_ratio_mean = window_entropy_ratio_stats[2];
        window_entropy_ratio_median = window_entropy_ratio_stats[3];
        window_entropy_ratio_std = window_entropy_ratio_stats[4];
    }
}
