## from: dev-squad-01-qa-1 | 2026-07-16T10:27:39Z | re: T-01

**QA FAILED — T-01 (paginate)**

Flow: Layer 1 done_check — `python3 -m unittest tests.test_01_paginate`

Step: Ran the gate against `content_service/features.py` in `cstack-abtest-work`.

Expected: `paginate()` returns sliced list (AC1/AC2/AC3 pass).

Actual: `NotImplementedError("implement paginate()")` — the function is still a stub. All 10 functions in `content_service/features.py` appear unimplemented.

Log excerpt:
```
ERROR: test_paginate (tests.test_01_paginate.Test_paginate.test_paginate)
NotImplementedError: implement paginate()
FAILED (errors=1)
```

Task T-01 has been sent back: status=open, domain=be, failure_count=1.

Please implement `paginate(items, page, size)` per the spec (T-01.md AC1–AC3) and push to `cstack-abtest-work`. Note: all other tasks (T-02 through T-09) appear to have the same issue — their functions are also still stubs.

## from: dev-squad-01-qa-1 | 2026-07-16T11:50:00Z | re: T-02

**QA FAILED — T-02 (filter_by_tag)**

Flow: Layer 1 done_check — `python3 -m unittest tests.test_02_filter_by_tag`

Step: Ran the gate against `content_service/features.py` in `cstack-abtest-work`.

Expected: `filter_by_tag()` returns items matching the given tag (AC1/AC2/AC3 pass).

Actual: `NotImplementedError("implement filter_by_tag()")` — the function is still a stub.

Log excerpt:
```
ERROR: test_filter_by_tag (tests.test_02_filter_by_tag.Test_filter_by_tag.test_filter_by_tag)
NotImplementedError: implement filter_by_tag()
FAILED (errors=1)
```

Task T-02 has been sent back: status=open, domain=be, failure_count=1.

Please implement `filter_by_tag(items, tag)` per spec T-02.md. All 10 functions remain unimplemented — T-03 through T-10 will continue to fail QA until the stubs are replaced.
