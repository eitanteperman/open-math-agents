# Runbook: proving problems for lefttosolve.com (credited to eitanteperman)

Technical reference for the autonomous run. The process itself is in the prompt the owner pasted.

## Files and tools
- `scripts/setup.sh`: installs Lean (elan release binary, never curl|sh), clones the site's tools and
  formal-conjectures at the pinned commit, fetches the Mathlib cache. Prints READY.
- `scripts/ship.sh <id> <proof.lean>`: claim, official check, push one-file branch, queue, wait for PR, release.
- `$WORK/oma` = upstream tools clone (tools/check.sh, tools/lint.py, data/catalog.json).
  `$WORK/oma/.oma/formal-conjectures` = Lean project everything compiles against. `$WORK/wip` = scratch proofs.
- Compile a scratch proof: `cd $WORK/oma/.oma/formal-conjectures && lake env lean $WORK/wip/<name>.lean`.
  First `lake build <Module>` once (e.g. `lake build FormalConjectures.OEIS.«181078»`) so the import is built.
- Never run the official check from anywhere but `$WORK/oma` (ship.sh does it for you).

## The file the checker accepts
- Line 1 is the single import it was given. Header comments, then helpers, then exactly one
  `theorem OMA.solution : type_of% @<decl> := by ...` (or `OMA.disproof : ¬ (type_of% @<decl>)`).
- Allowed commands: theorem, lemma, def, abbrev, structure, inductive, instance, open, namespace, section, end,
  variable, universe, `set_option maxHeartbeats|maxRecDepth|synthInstance.* <number> in`, `@[simp]`.
- Forbidden anywhere in code (comments are fine): sorry, admit, axiom, native_decide, unsafe, partial, opaque,
  implemented_by, extern, macro*, syntax*, elab*, notation*, infix, prefix, postfix, initialize, run_cmd, attribute,
  meta, IO, `import Lean`, every `#command` (#check, #print, #eval ...), and the DOUBLE-QUOTE character in code.
- `decide +kernel` and `by decide` are allowed. Only axioms propext, Classical.choice, Quot.sound may appear.
- Never use the upstream declaration itself or anything upstream that is still `sorry`. The brief
  (`https://lefttosolve.com/p/<id>/agent.txt`) lists which lemmas are proved and which are sorry.

## Lean pitfalls seen in practice (Lean v4.33, very recent Mathlib)
- ALWAYS look at the real statement first: `set_option pp.universes true` + `#check @decl` in a scratch file.
  Example trap: a statement with hypothesis and conclusion in two different universes (`u_1`, `u_2`) needs a
  universe-transfer lemma; a naive proof does not typecheck.
- Mathlib names move. Search the source instead of guessing: `grep -rn "theorem foo" $FC/.lake/packages/mathlib/Mathlib`.
  Deprecated (still warns, fix when cheap): `push_neg` -> `push Not`, `Set.mem_setOf_eq` -> `Set.mem_ofPred_eq`.
- `simp` can loop or hit max recursion on explicit matrices: state the matrix literally with `!![...]`,
  raise `set_option maxRecDepth 10000 in`, expand determinants by hand (`Matrix.det_succ_row_zero`, `det_fin_three`).
- `rw` fails with "motive is not type correct" on dependent types: rewrite the other end, use `simp only`,
  or `obtain ⟨...⟩` / `convert ... using n`.
- Finite checks: `decide +kernel`, `norm_num`, `fin_cases i <;> simp`, `interval_cases`.
- Power-series substitution: `PowerSeries.coeff_subst'` plus the fact that `X ^ d ∣ L ^ d` when `L` has zero
  constant term gives a finite sum; this proved a whole family of OEIS "Hanna exponential series" terms.
- Warnings never fail the check; only errors and forbidden axioms do.

## Choosing problems
- API: `GET https://lefttosolve.com/api/problems?kind=known|warmup&sort=easiest&limit=100&offset=N` ->
  items with `id, difficulty, solved, liveAgents, claimed, excerpt`; points = see `/api/problems/<id>`.
  `GET /api/problems/<id>` has `lean` (exact target), `points`, `solution` (who solved it).
  Save JSON to disk and filter with python; never print the whole catalog.
- Candidate = `solved` false, `liveAgents` 0, `claimed` false. Open the brief and read "WHAT OTHERS TRIED":
  best is "Nothing yet: you are early". Skip anything someone submitted in the last hour.
- Points are fixed by difficulty, not by proof effort. Prefer higher points when the proof looks feasible.
- Claiming does NOT lock a problem. ship.sh claims only after your proof compiled, to keep the window short.
- If `already_solved` comes back, discard the work and move on.

## Known infeasible (examined, do not retry without a new idea)
Busy Beaver BB_2/3/4/5 (needs exhaustive halting analysis), RegularPrimes.* and anything needing class numbers or
cyclotomic integers, QuadraticAlgebra discriminants (no ring of integers of Q(sqrt d) in Mathlib), Erdos311 delta bounds
(need the prime number theorem), Erdos44 greedy Sidon (counting bound falls short), Erdos1055.exists_p, Erdos23.n5,
Erdos210/Green40/NP-pair completeness variants (need substantial published theorems), Erdos375 gap bounds,
Arxiv.2607.05739.x_succ (depends on an unproved nonvanishing). Open problems: no counterexample found for
Erdos307 (coprime version, searched to large bounds), Erdos49, Erdos542, OeisA69004.

## Etiquette and honesty
- At most one request every few seconds to lefttosolve.com. Heartbeat a held lease every 5 minutes
  (`POST /api/desk/beat?lease=...`); HTTP 410 means stop.
- Release honestly (`/api/desk/release?lease=...&reason=too_hard|missing_lemma|does_not_elaborate|other`).
- These proofs formalize known results unless the problem kind is "open". Report them that way.
