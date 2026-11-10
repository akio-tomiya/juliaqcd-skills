# Building a package on JuliaQCD

Read this before creating the package for a missing part, and before
comparing it with another code. It collects what went wrong and what
helped when measurement packages were built on JuliaQCD v1. None of it is
a tested script here.

## Layout and compat

- Keep the analysis layer on the standard library only, and load the
  JuliaQCD packages through a package extension (`[weakdeps]` and
  `[extensions]` in `Project.toml`). The analysis then works without
  JuliaQCD, and the main CI job stays light.
- Give every dependency a compat entry, standard libraries included. The
  JuliaQCD v1 packages need Julia 1.11 or later; if the package itself
  supports an older Julia, test the extension in a separate environment
  under `test/` with its own `Project.toml`, as a separate CI job.
- Do not commit `Manifest.toml` to a package repository. A Manifest that
  points to a developer's local path breaks CI at dependency resolution.
- Before publishing, and before any comparison, build an environment from
  the registered versions only and run `Pkg.test` from scratch. Check what
  is actually loaded with `pathof` and `pkgversion`: a locally developed
  dependency can be a slightly modified fork.

## Depending on JuliaQCD internals

- If a non-public accessor is unavoidable (for example to read the array
  inside a distributed lattice), call it from one function in the
  extension only, and raise an explicit error where it does not apply (a
  process grid other than 1), instead of returning wrong values.
- Deprecated paths upstream (old operators under `deprecated/`) may no
  longer be covered by upstream tests after other parts change; one such
  path returned a wrong clover term for SU(2) and stopped for SU(3). Pin
  the path you use with your own tests, and run them after every upstream
  update.
- Where your convention differs from upstream (the γ-matrix basis, for
  example), write the conversion in one place and fix it with a test; in
  component comparisons pass upstream's γ matrices to the reference.
- A setting upstream does not accept (for example a boundary phase of 0
  for a Dirichlet boundary) can be built outside it (setting the temporal
  links across the boundary to zero). Check the substitute against
  another implementation of the same feature before use, and ask upstream
  for the feature in an issue.
- Report an upstream bug or convention mismatch with a minimal
  reproduction and a comparison script, as an issue or a pull request,
  besides working around it.

## Tests

- Compute the same quantity two independent ways and compare: a fast
  method (for example momentum space) against a slow, direct reference
  (for example the Wick contractions written as determinants or sums over
  permutations), on a small lattice.
- Free field (unit links): compare with the analytic propagator in
  momentum space, component by component.
- A random local gauge transformation: gauge-invariant quantities do not
  change, propagators transform covariantly.
- Make the gauge group a type parameter and run the same tests for SU(2),
  SU(3), and SU(4); code that assumes N = 3 shows up when N changes.
- Random test data must not depend on the Julia version: use fixed values
  or a stable generator (StableRNGs); a test that drew random components
  failed only on one Julia version.
- In CI, run tests that finish in seconds to minutes (4⁴, 4³×8), including
  one small end-to-end run of the extension. Production-size checks and
  comparisons with other codes go into scripts whose logs are kept with
  the results, outside CI.
- Run the test suite at both the lower compat bound and the newest
  versions, not on one Julia and one dependency version only.
- Before production, run the production driver end to end on a small
  lattice, then measure one production-size configuration for time and
  memory before choosing the scale.

## Comparing with another code

- Feed the same configuration to both. After any format conversion, first
  compare the average plaquette.
- Write down the conventions of both sides before comparing, and align
  them. Mismatches that occurred: the γ-matrix basis, the sign of the
  clover term (one code stored c_SW with the opposite sign), the
  construction of the field strength (whether the trace is subtracted
  from (Q − Q†)/8), and the temporal boundary condition. Also check the
  hopping normalization (κ or mass), whether source positions start at 0
  or 1, and the antiperiodic phase.
- Start with gauge-invariant, simple quantities (plaquette, meson
  two-point function C(t)), and compare propagator components only after
  that: components agree only when every gauge and basis convention
  matches, so starting with them does not narrow down a cause.
- Set the tolerance from the solver residual and the range of C(t). With
  solves to a relative residual of about 1e-12, C(t) agreed to 1e-11 to
  1e-13 at most times, and to about 1e-9 where C(t) is smallest
  (cancellation). Report the relative difference per time slice to see
  where it grows.
- A small difference far above rounding (about 0.1 %) is a convention
  difference, not rounding; the field-strength trace gave 0.07 to 0.26 %
  for SU(3). The codes compute the same thing only once one is aligned to
  the other and they agree to about 1e-12.

## Calculations with many terms (contractions, correlators)

- Write the slow, plain reference first; make the fast version agree with
  it on a small lattice. Keep exchange terms separable, so their sign and
  factor can be checked alone.
- Use what symmetry fixes: components that vanish by time reversal,
  parity, or the cubic-group projection; the free-field solution; the
  reduction to a single source.
- A feature that combines several sources must give exactly the result of
  solving source by source. A shifted-link trick (solving at a fixed source
  position on links shifted in time) must reproduce the shifted links
  exactly and the result of the original source position, to rounding,
  including antiperiodic boundaries.
- Jackknife the whole analysis (normalization, time derivatives, fits),
  not only the final number. When two analysis methods disagree, build
  synthetic data from the fitted result plus excited states and periodic
  images, and pass it through the same analysis: if it shows the same
  disagreement, the cause is explained.

## Mistakes agents made

- Writing their own version of a part upstream has and making it the
  production default (an own BiCGStab "because it is easier to test").
  Upstream is the default; an own version is a reference in the tests.
- Estimating the cost without measuring. Measure one unit first.
- Calling a convention difference rounding ("almost agree" at 0.1 %).
  Set the tolerance before the comparison.
- Calling a conditional agreement a reproduction. Report the size of the
  errors, the shift of the central value, and differences of method.
- "Tests pass" after one Julia and one dependency version.
- Using deprecated upstream paths or internals without noticing.
- Removing a lock or a half-written file of a long process without
  checking that its process id is dead, or forgetting it and starting a
  second copy.

## Also

- Keep the before-and-after comparison script for every change (speed or
  convention); it serves again after an upstream update.
- Decide success from what a machine can check: return values, residuals,
  norms of differences.
- Publish from a branch without history when the development history holds
  unpublished work.
- Performance points from the same work are in
  `juliaqcd/references/performance.md`.
