#!/usr/bin/env python3
"""Turns a posts-scroll-perf.sh recording into a per-phase Markdown report.

Usage: posts-scroll-perf-report.py <recording dir>

Reads probe.log (the performance probe's log lines plus the UI test's phase markers)
and processes.csv (CPU and memory per process, once a second), and reports for each
phase of the workout what the reader would have felt: app hitches, leaps,
dropped frames, content resizing above the viewport, endless-scroll inserts, and
CPU and memory.
"""

import csv
import json
import os
import re
import sys
from collections import Counter, defaultdict

LINE = re.compile(r'^\S+ (\d\d:\d\d:\d\d\.\d+) \S+\s+\S+ \[[^\]]*\] (.*)$')
PHASE = re.compile(r'\[ui-test\] phase (\S+) (start|end)')
NATIVE = re.compile(r'native scroll (\{.*\})')
JS = re.compile(r' js (\{.*)$')
CHUNK = re.compile(r'\[t\d+ append (\d+) posts (\d+)-(\d+)\] \+(\d+)ms (built and rendered|appended to document)')
FETCH = re.compile(r'\[t\d+ append (\d+)\] \+(\d+)ms fetched and scraped')
# Where in a gesture the app's scroll monitor saw each leap, in report order.
LEAP_MOMENTS = ('touchDown', 'dragging', 'release', 'decelerating', 'resize')


def load_lines(path):
    lines = []
    with open(path, errors='replace') as f:
        for raw in f:
            m = LINE.match(raw.rstrip('\n'))
            if m:
                lines.append((m.group(1), m.group(2)))
    return lines


def phases_from(lines):
    starts, phases = {}, []
    for t, msg in lines:
        m = PHASE.search(msg)
        if not m:
            continue
        name, edge = m.groups()
        if edge == 'start':
            starts[name] = t
        elif name in starts:
            phases.append((name, starts.pop(name), t))
    return phases


def field(text, name):
    """Pulls one field from a JSON line the log may have truncated."""
    m = re.search(r'"%s":(\{(?:[^{}]|\{[^{}]*\})*\}|\[[^\]]*\]|"[^"]*"|-?[\d.]+|null|true|false)' % re.escape(name), text)
    if not m:
        return None
    try:
        return json.loads(m.group(1))
    except ValueError:
        return None


def summarize(lines, start, end):
    s = defaultdict(float)
    s['worst_hitch'] = s['worst_gap'] = s['largest_leap'] = 0
    s['leaps_at'], s['largest_leap_at'] = Counter(), Counter()
    s['growth_by'] = Counter()
    chunk_starts, insert_times, fetch_times = {}, [], []
    for t, msg in lines:
        if not (start <= t <= end):
            continue
        if m := NATIVE.search(msg):
            r = json.loads(m.group(1))
            s['gestures'] += 1
            s['gesture_ms'] += r['durationMs']
            s['hitch_ms'] += r['hitchTimeMs']
            s['hitches'] += r['hitches']
            s['worst_hitch'] = max(s['worst_hitch'], r['worstHitchMs'])
            s['reversals'] += r['reversals']
            s['reversal_px'] += r['reversalPx']
            s['leaps'] += r['leaps']
            s['largest_leap'] = max(s['largest_leap'], r['largestLeapPx'])
            s['leaps_at'].update(r.get('leapsAt', {}))
            for at, px in r.get('largestLeapPxAt', {}).items():
                s['largest_leap_at'][at] = max(s['largest_leap_at'][at], px)
        elif (m := JS.search(msg)) and '"kind":"scroll"' in msg and '"type":"frames"' in msg:
            text = m.group(1)
            s['frames'] += field(text, 'frames') or 0
            s['dropped'] += field(text, 'droppedFrames') or 0
            s['long_frames'] += field(text, 'longFrames') or 0
            s['worst_gap'] = max(s['worst_gap'], field(text, 'maxFrameGapMs') or 0)
            resizes = field(text, 'resizesAboveViewport') or {}
            s['first_draws'] += resizes.get('firstRender', 0)
            s['growths'] += resizes.get('growth', 0)
            s['resize_px'] += resizes.get('px', 0)
            s['growth_by'].update(resizes.get('growthBy', {}))
        elif m := CHUNK.search(msg):
            key = m.group(1, 2)
            if m.group(5) == 'built and rendered':
                chunk_starts[key] = int(m.group(4))
            elif key in chunk_starts:
                insert_times.append(int(m.group(4)) - chunk_starts.pop(key))
        elif m := FETCH.search(msg):
            fetch_times.append(int(m.group(2)))
    s['inserts'] = len(insert_times)
    s['worst_insert'] = max(insert_times, default=0)
    s['fetches'] = len(fetch_times)
    s['avg_fetch'] = sum(fetch_times) / len(fetch_times) if fetch_times else 0
    return s


def processes(path, start, end):
    """Average CPU and last memory reading per process name within [start, end]. The busiest WebContent process is the posts view's."""
    per_pid = defaultdict(lambda: {'cpu': [], 'mem': None, 'name': '?'})
    if not os.path.exists(path):
        return {}
    with open(path) as f:
        for row in csv.DictReader(f):
            if not (start[:8] <= row['time'] <= end[:8]):
                continue
            p = per_pid[row['pid']]
            p['name'] = row['process'] or '?'
            try:
                p['cpu'].append(float(row['cpu']))
            except ValueError:
                pass
            p['mem'] = row['mem']
    result = {}
    for pid, p in per_pid.items():
        if not p['cpu']:
            continue
        label = {'AwfulDebug': 'app', 'com.apple.WebKit.GPU': 'GPU', 'com.apple.WebKit.Networking': 'network'}.get(p['name'], p['name'])
        avg = sum(p['cpu']) / len(p['cpu'])
        if label == 'com.apple.WebKit.WebContent':
            label = 'web content'
            if label in result and result[label][0] >= avg:
                continue
        result[label] = (avg, max(p['cpu']), p['mem'])
    return result


def main():
    rec = sys.argv[1]
    lines = load_lines(os.path.join(rec, 'probe.log'))
    phases = phases_from(lines)
    if not phases:
        print('# Posts scroll performance\n\nNo phases found in probe.log; did the test run? See test.log.')
        return

    stats = [summarize(lines, start, end) for _, start, end in phases]
    procs = [processes(os.path.join(rec, 'processes.csv'), start, end) for _, start, end in phases]

    def secs(start, end):
        a = [float(x) for x in start.split(':')]
        b = [float(x) for x in end.split(':')]
        return (b[0] - a[0]) * 3600 + (b[1] - a[1]) * 60 + (b[2] - a[2])

    rows = [
        ('Duration', [f"{secs(a, b):.0f}s" for _, a, b in phases]),
        ('**App (native scroll view)**', ['' for _ in phases]),
        ('Gestures', [f"{s['gestures']:.0f}" for s in stats]),
        ('Hitch ratio (under 5 ms/s is good)', [f"{s['hitch_ms'] / s['gesture_ms'] * 1000:.1f} ms/s" if s['gesture_ms'] else '-' for s in stats]),
        ('Hitches (worst)', [f"{s['hitches']:.0f} ({s['worst_hitch']:.0f}ms)" for s in stats]),
        ('Offset reversals', [f"{s['reversals']:.0f} ({s['reversal_px']:.0f}px)" for s in stats]),
        ('Leaps (largest)', [f"{s['leaps']:.0f} ({s['largest_leap']:.0f}px)" for s in stats]),
    ]
    rows += [
        (f'&nbsp;&nbsp;{at}', [f"{s['leaps_at'][at]} ({s['largest_leap_at'][at]}px)" if s['leaps_at'][at] else '0' for s in stats])
        for at in LEAP_MOMENTS
    ]
    rows += [
        ('**Page (web content)**', ['' for _ in phases]),
        ('Resizes above viewport: first draw / growth', [f"{s['first_draws']:.0f} / {s['growths']:.0f} ({s['resize_px']:.0f}px)" for s in stats]),
        ('&nbsp;&nbsp;growth in posts with', [', '.join(f"{cause} {n}" for cause, n in s['growth_by'].most_common()) or '-' for s in stats]),
        ('Frames, dropped', [f"{s['frames']:.0f}, {s['dropped']:.0f} ({s['dropped'] / s['frames'] * 100:.1f}%)" if s['frames'] else '-' for s in stats]),
        ('Long frames (worst gap)', [f"{s['long_frames']:.0f} ({s['worst_gap']:.0f}ms)" if s['frames'] else '-' for s in stats]),
        ('**Endless scroll**', ['' for _ in phases]),
        ('Pages fetched (avg fetch)', [f"{s['fetches']} ({s['avg_fetch']:.0f}ms)" if s['fetches'] else '0' for s in stats]),
        ('Chunks inserted (worst insert)', [f"{s['inserts']} ({s['worst_insert']}ms)" if s['inserts'] else '0' for s in stats]),
        ('**Processes (avg CPU / peak, memory at end)**', ['' for _ in phases]),
    ]
    for name in ('app', 'web content', 'GPU', 'network'):
        rows.append((name, [f"{p[name][0]:.1f}% / {p[name][1]:.0f}%, {p[name][2]}" if name in p else '-' for p in procs]))

    print('# Posts scroll performance\n')
    run = os.path.join(rec, 'run.txt')
    if os.path.exists(run):
        with open(run) as f:
            print(''.join(f'{line.rstrip()}  \n' for line in f))
    print('| | ' + ' | '.join(name for name, _, _ in phases) + ' |')
    print('|---|' + '---|' * len(phases))
    for label, values in rows:
        print(f'| {label} | ' + ' | '.join(values) + ' |')

    # The page as it stood at the end.
    last = next((msg for _, msg in reversed(lines) if '"reason":' in msg), None)
    if last:
        # Only timed when the document has changed since, so take the latest timing.
        relayout = next((field(msg, 'relayoutMs') for _, msg in reversed(lines) if field(msg, 'relayoutMs') is not None), None)
        if relayout is not None:
            last = re.sub(r'"relayoutMs":null', f'"relayoutMs":{relayout}', last)
        print('\n**Document at the end:** ' + ', '.join(
            f'{label} {field(last, key)}' for label, key in (
                ('posts', 'posts'), ('height', 'docHeight'), ('DOM nodes', 'domNodes'),
                ('never-drawn posts', 'unrenderedPosts'), ('full relayout ms', 'relayoutMs'),
                ('est. decoded image MB', 'estDecodedImageMB'))
            if field(last, key) is not None))
        dividers = field(last, 'pageDividers')
        if dividers:
            print(f"\n**Page dividers:** {', '.join(dividers)}")

    print('\nSimulator numbers run on the Mac\'s CPU, so compare runs with each other rather than with a phone.')


if __name__ == '__main__':
    main()
