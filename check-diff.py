#!/usr/bin/python3
# Compare two directories (maybe only a subdirectory of them) and add
# GitHub annotations where they're different.

import argparse
import difflib
import io
import itertools
import os.path
import sys

def annotate(output, path, start_line, end_line, severity, message):
    '''start_line is zero-indexed; end_line is zero-indexed and points to
    the first line not matched.'''
    if end_line == start_line + 1:
        title = f'Line {start_line + 1}'
    else:
        title = f'Lines {start_line + 1}-{end_line}'
    print(
        f'::{severity} file={path},line={start_line + 1},endLine={end_line},title={title}::{message}',
        file=output
    )


def diff(canon_path, left_lines, right_lines, severity, output=sys.stdout):
    seq = difflib.SequenceMatcher(a=left_lines, b=right_lines, autojunk=False)
    ok = True
    matching = seq.get_matching_blocks()
    # Add sentinel at the beginning, corresponding to the sentinel at the
    # end, to simplify handling of disjoint files where one of them is empty
    matching.insert(0, difflib.Match(0, 0, 0))
    for first, second in itertools.pairwise(matching):
        ok = False
        left_end = first.a + first.size
        right_end = first.b + first.size
        left_start = second.a
        right_start = second.b
        if right_end != right_start and left_end != left_start:
            annotate(output, canon_path, right_end, right_start, severity, 'Unexpected change')
        elif right_end != right_start:
            annotate(output, canon_path, right_end, right_start, severity, 'Unexpected addition')
        elif left_end != left_start:
            # message before the removal is a bit more obvious than after it
            annotate(output, canon_path, right_start - 1, right_start, severity, 'Unexpected removal on next line')
    return ok


def recursive_diff(left_root, right_root, subpath, severity):
    # this ignores files that are only in the left root
    subroot = os.path.join(right_root, subpath)
    if os.path.isdir(subroot):
        def handle_error(e):
            raise e
        iter = os.walk(subroot, onerror=handle_error)
    else:
        iter = [(os.path.dirname(subroot), [], [os.path.basename(subroot)])]

    ok = True
    for (dirpath, dirnames, filenames) in iter:
        if os.path.relpath(dirpath, right_root) == '.git':
            # stop descent and ignore
            dirnames[:] = []
            continue
        for filename in filenames:
            right_path = os.path.join(dirpath, filename)
            canon_path = os.path.relpath(right_path, right_root)
            left_path = os.path.join(left_root, canon_path)
            with open(left_path) as fh:
                left = fh.readlines()
            with open(right_path) as fh:
                right = fh.readlines()
            ok = diff(canon_path, left, right, severity) and ok
    return ok


def selftest_one(left, right, expected):
    buf = io.StringIO()
    diff('a/b/c', left, right, 'alert!', buf)
    if buf.getvalue() != expected:
        raise Exception(f'Selftest returned unexpected value:\n{buf.getvalue()}')


def selftest():
    selftest_one(
        ['one', 'two', 'three', 'four', 'five', 'seven', 'eight', 'nine'],
        ['one', 'two', 'none', 'not', 'four', 'five', 'six', 'seven', 'nine'],
        '''::alert! file=a/b/c,line=3,endLine=4,title=Lines 3-4::Unexpected change
::alert! file=a/b/c,line=7,endLine=7,title=Line 7::Unexpected addition
::alert! file=a/b/c,line=8,endLine=8,title=Line 8::Unexpected removal on next line
''')
    # Check disjoint files
    selftest_one(
        ['a', 'b', 'c'],
        ['d', 'e', 'f'],
        '::alert! file=a/b/c,line=1,endLine=3,title=Lines 1-3::Unexpected change\n'
    )
    selftest_one(
        ['a', 'b', 'c'],
        [],
        '::alert! file=a/b/c,line=0,endLine=0,title=Line 0::Unexpected removal on next line\n'
    )
    selftest_one(
        [],
        ['d', 'e', 'f'],
        '::alert! file=a/b/c,line=1,endLine=3,title=Lines 1-3::Unexpected addition\n'
    )
    selftest_one(
        [],
        [],
        '',
    )
    # Check EOF behavior
    selftest_one(
        ['one', 'two', 'three', 'four'],
        ['one', 'two', 'five', 'six'],
        '::alert! file=a/b/c,line=3,endLine=4,title=Lines 3-4::Unexpected change\n'
    )
    selftest_one(
        ['one', 'two'],
        ['one', 'two', 'three', 'four'],
        '::alert! file=a/b/c,line=3,endLine=4,title=Lines 3-4::Unexpected addition\n'
    )
    selftest_one(
        ['one', 'two', 'three', 'four'],
        ['one', 'two'],
        '::alert! file=a/b/c,line=2,endLine=2,title=Line 2::Unexpected removal on next line\n'
    )


def main():
    selftest()

    parser = argparse.ArgumentParser(description='Compare genericized diffs and add GitHub annotations.')
    parser.add_argument('basedir',
            help='unmodified source tree (left side of comparison)')
    parser.add_argument('patchdir', nargs='?', default='.',
            help='modified source tree (right side of comparison)')
    parser.add_argument('path', nargs='?', default='.',
            help='file or subdirectory within tree')
    parser.add_argument('--severity', default='warning',
            choices=['notice', 'warning', 'error'],
            help='annotation severity (default: warning)')
    parser.add_argument('--selftest', action='store_true',
            help='only run self-test')
    args = parser.parse_args()

    if args.selftest:
        return 0

    ok = recursive_diff(args.basedir, args.patchdir, args.path, args.severity)
    return 0 if ok else 1


if __name__ == '__main__':
    sys.exit(main())
