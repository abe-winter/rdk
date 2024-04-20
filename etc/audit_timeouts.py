#!/usr/bin/env python
"audit timeouts in github workflows"

import glob, logging, pprint, collections, argparse
import yaml

logger = logging.getLogger(__name__)

def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--fix', type=int, help="if non-zero, set default timeout-minutes where missing")
    args = p.parse_args()

    logging.basicConfig(level=logging.INFO)

    # errors is {path: [job_id]}
    errors = collections.defaultdict(list)
    for path in glob.glob('.github/workflows/*.y*ml'):
        logger.debug("checking %s", path)
        with open(path) as f:
            # todo: preserve order, don't convert 'on' to True
            blob = yaml.safe_load(f)
        nfixed = 0
        for job_id, job in blob['jobs'].items():
            if 'timeout-minutes' in job:
                continue
            errors[path].append(job_id)
            if args.fix:
                nfixed += 1
                job['timeout-minutes'] = str(args.fix)
        if nfixed:
            logger.info("writing %d fixes back to %s", nfixed, path)
            with open(path, 'w') as f:
                yaml.safe_dump(blob, f)

    pprint.pprint(errors)

if __name__ == '__main__':
    main()
