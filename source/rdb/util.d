module rdb.util;

import std.format;
import std.array;

import minlog;

Logger logger = Logger(Verbosity.info);

string human_file_size(size_t file_size) {
    auto units = ["B", "KiB", "MiB", "GiB", "TiB", "PiB", "EiB", "ZiB"];

    size_t unit_index = 0;
    while (file_size >= 1024 && unit_index < cast(long) units.length - 1) {
        file_size /= 1024;
        unit_index++;
    }

    return format("%s %s", file_size, units[unit_index]);
}

/** calculate min, max, mean, med, std of a list of numbers */
double[] five_point_summary(double[] samples) {
    import std.algorithm.sorting : sort;

    assert(!samples.empty, "samples must not be empty");

    double min = 0;
    double max = 0;
    double mean = 0;
    double med = 0;
    double std = 0;

    // make a local copy of the samples so we can sort them
    samples = samples.dup;

    samples.sort();

    min = samples[0];
    max = samples[cast(long) samples.length - 1];

    foreach (sample; samples) {
        mean += sample;
    }
    mean /= samples.length;

    if (samples.length % 2 == 0) {
        med = (samples[cast(long) samples.length / 2] + samples[cast(long) samples.length / 2 - 1]) / 2;
    } else {
        med = samples[cast(long) samples.length / 2];
    }

    foreach (sample; samples) {
        std += (sample - mean) ^^ 2;
    }
    std /= samples.length;

    return [min, max, mean, med, std];
}
