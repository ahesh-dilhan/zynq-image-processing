#!/usr/bin/env python3
"""Bit-accurate software model for the cropped 3x3 RTL mean filter."""

from __future__ import annotations

import argparse
from pathlib import Path
from typing import Sequence


def mean_filter_cropped(
    pixels: Sequence[int], width: int, height: int, pixel_width: int = 8
) -> list[int]:
    """Return the valid-window mean using the RTL's integer truncation rule."""
    if width < 3 or height < 3:
        raise ValueError("width and height must both be at least 3")
    if len(pixels) != width * height:
        raise ValueError("pixel count does not match width * height")
    if pixel_width < 1:
        raise ValueError("pixel_width must be positive")

    maximum = (1 << pixel_width) - 1
    if any(pixel < 0 or pixel > maximum for pixel in pixels):
        raise ValueError(f"pixels must be in the range 0..{maximum}")

    output: list[int] = []
    for top in range(height - 2):
        for left in range(width - 2):
            window_sum = sum(
                pixels[(top + row) * width + left + column]
                for row in range(3)
                for column in range(3)
            )
            output.append(window_sum // 9)
    return output


def demo_frame(width: int, height: int, pixel_width: int = 8) -> list[int]:
    """Generate the same deterministic pattern used by the HDL testbench."""
    modulus = 1 << pixel_width
    return [
        (row * 29 + column * 7 + row * column * 3) % modulus
        for row in range(height)
        for column in range(width)
    ]


def write_pgm(path: Path, pixels: Sequence[int], width: int, height: int) -> None:
    """Write an 8-bit binary PGM without third-party image libraries."""
    path.parent.mkdir(parents=True, exist_ok=True)
    header = f"P5\n{width} {height}\n255\n".encode("ascii")
    path.write_bytes(header + bytes(pixels))


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--width", type=int, default=8)
    parser.add_argument("--height", type=int, default=6)
    parser.add_argument("--output-dir", type=Path, default=Path("build/reference"))
    args = parser.parse_args()

    source = demo_frame(args.width, args.height)
    filtered = mean_filter_cropped(source, args.width, args.height)
    write_pgm(args.output_dir / "input.pgm", source, args.width, args.height)
    write_pgm(
        args.output_dir / "mean_3x3_cropped.pgm",
        filtered,
        args.width - 2,
        args.height - 2,
    )

    expected_hex = "".join(f"{pixel:02x}\n" for pixel in filtered)
    (args.output_dir / "expected.hex").write_text(expected_hex, encoding="ascii")
    print(
        f"generated {args.width}x{args.height} input and "
        f"{args.width-2}x{args.height-2} reference output in {args.output_dir}"
    )


if __name__ == "__main__":
    main()
