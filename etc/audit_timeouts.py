#!/usr/bin/env python
"audit timeouts in github workflows"

import glob, logging, pprint, argparse, re
from typing import List, Dict
import yaml

logger = logging.getLogger(__name__)

def build_index_map(tokens: List[yaml.Event]) -> Dict[tuple, int]:
    """
    takes tokens from yaml.parse().
    returns a lookup dictionary for finding the token corresponding to a semantic location in the document.
    """
    pattern = [yaml.ScalarEvent, yaml.MappingStartEvent]
    stack = []
    index_map = {}
    for i in range(len(tokens)):
        if list(map(type, tokens[max(0, i-1):i+1])) == pattern:
            stack.append(tokens[i-1].value)
            # [1:] here because of initial null from document-level anonymous mapping
            index_map[tuple(stack[1:])] = i
        elif type(tokens[i]) is yaml.MappingStartEvent:
            stack.append(None) # this is an anonymous map in a sequence
        elif type(tokens[i]) is yaml.MappingEndEvent:
            stack.pop()
    return index_map

def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--fix', type=int, help="if non-zero, set default timeout-minutes where missing")
    p.add_argument('--max', type=int, help="if present, maximum files to process")
    args = p.parse_args()

    logging.basicConfig(level=logging.INFO)

    # errors is {path: [job_id]}
    errors = {}
    nfiles = 0
    for path in glob.glob('.github/workflows/*.y*ml'):
        nfiles += 1
        if args.max is not None and nfiles > args.max:
            logger.info('hit max files %d, stopping', args.max)
            break
        logger.debug("checking %s", path)
        with open(path) as f:
            blob = yaml.safe_load(f)
            f.seek(0)
            tokens: List[yaml.Event] = list(yaml.parse(f))
            f.seek(0)
            lines = f.readlines()
        jobs_to_fix = []
        for job_id, job in blob['jobs'].items():
            if 'timeout-minutes' in job:
                continue
            jobs_to_fix.append(job_id)
                # job['timeout-minutes'] = str(args.fix)
        errors[path] = jobs_to_fix
        if args.fix and jobs_to_fix:
            logger.info("writing fixes back to %s for %s", path, jobs_to_fix)
            index_map = build_index_map(tokens)
            for i, job_id in enumerate(jobs_to_fix):
                tok = tokens[index_map['jobs', job_id] + 1]
                # note: this approach completely breaks if someone does one-line '{}' style maps
                line = lines[tok.start_mark.line + i]
                indent = re.match(r'(\s*)', line).group(0)
                lines.insert(tok.start_mark.line + i, f"{indent}timeout-minutes: {args.fix}\n")
            with open(path, 'w') as f:
                f.writelines(lines)
    pprint.pprint(errors)

if __name__ == '__main__':
    main()
