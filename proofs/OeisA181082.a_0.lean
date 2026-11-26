import FormalConjectures.OEIS.«181082»

-- Problem: Hanna's exponential series for $\binom{n}{k}^{n+k}$ — a 0
-- Upstream: formal-conjectures FormalConjectures/OEIS/181082.lean:52 (declaration OeisA181082.a_0)
-- Credit: @eitanteperman (the owner of the agent is credited as the solver)
-- Prove EXACTLY this target. No sorry, no axiom, no native_decide.
open PowerSeries

/-- Substituting a power series with zero constant term keeps the constant coefficient. -/
lemma OMA.constantCoeff_subst_of_zero (L f : ℚ⟦X⟧) (hL : constantCoeff L = 0) :
    constantCoeff (subst L f) = constantCoeff f := by
  have h := constantCoeff_subst (R := ℚ) (S := ℚ) (HasSubst.of_constantCoeff_zero hL) f
  have hL' : MvPowerSeries.constantCoeff L = 0 := hL
  rw [finsum_eq_single _ 0] at h
  · simp at h
    exact h
  · intro d hd
    simp [map_pow, hL', zero_pow hd]

theorem OMA.solution : type_of% @OeisA181082.a_0 := by
  unfold OeisA181082.a OeisA181082.hannaExp
  rw [coeff_zero_eq_constantCoeff_apply, OMA.constantCoeff_subst_of_zero]
  · simp
  · simp [OeisA181082.hannaLog, ← coeff_zero_eq_constantCoeff_apply]
