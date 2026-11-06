# Helpers for Wilson and Wilson–clover fermions on JuliaQCD v1
# (LatticeDiracOperators, QCDMeasurements). Load after Gaugefields and
# measure_common.jl. Four dimensions only.

using LatticeDiracOperators
using QCDMeasurements
using LinearAlgebra

"The 16 local meson channels, in the order of standard_local_meson_channels()."
const MESON_CHANNELS = ["scalar", "pseudoscalar",
    "vector_1", "vector_2", "vector_3", "vector_4",
    "axial_1", "axial_2", "axial_3", "axial_4",
    "tensor_12", "tensor_13", "tensor_14", "tensor_23", "tensor_24", "tensor_34"]

"Index ranges of the interior (halo excluded) of a v1 fermion field."
function fermion_ranges(x)
    nw = x.f.nw
    return (Colon(), Colon(), (nw+1:nw+n for n in (x.NX, x.NY, x.NZ, x.NT))...)
end

"""
    fermion_field(U; bc=(1, 1, 1, -1))

A Wilson fermion field on the lattice of `U` with boundary phases `bc`.

In LatticeDiracOperators 1.1 the phases that act are those stored in the
field (`x.f.phases`). The `"boundarycondition"` entry of the operator's
parameters is not used, and `Initialize_pseudofermion_fields(U[1], "Wilson";
boundarycondition=...)` drops the keyword and always gives (1, 1, 1, −1).
Hence the direct constructor here.
"""
function fermion_field(U; bc=(1, 1, 1, -1))
    x = LatticeDiracOperators.Dirac_operators.Initialize_WilsonFermion(U[1];
        nowing=true, boundarycondition=collect(bc))
    x.f.phases == collect(bc) || error("fermion field has phases $(x.f.phases), asked for $bc")
    return x
end

"Write ψ[c, α, x, y, z, t] into the field `x` and fill its halo."
function set_fermion!(x, ψ)
    A = zeros(eltype(x.f.A), size(x.f.A))
    A[fermion_ranges(x)...] = ψ
    copyto!(x.f.A, A)
    set_wing_fermion!(x)
    return x
end

"The field `x` as an array ψ[c, α, x, y, z, t]."
get_fermion(x) = Array(x.f.A)[fermion_ranges(x)...]

"""
    dirac_parameters(; κ, cSW=0.0, bc=(1, 1, 1, -1), r=1.0)

Parameters for `Dirac_operator`: Wilson when `cSW == 0`, Wilson–clover
otherwise. Convention: D = 1 − κ H (− κ c_SW Σ_{μ<ν} γ_μγ_ν F_μν), the
hopping parameter κ = 1/(2 m₀ + 8r).
"""
dirac_parameters(; κ, cSW=0.0, bc=(1, 1, 1, -1), r=1.0) = Dict{String,Any}(
    "Dirac_operator" => cSW == 0 ? "Wilson" : "WilsonClover",
    "κ" => κ, "r" => r, "cSW" => cSW, "boundarycondition" => collect(bc),
    "eps_CG" => 1e-14, "MaxCGstep" => 5000, "verbose_level" => 0)

"D ψ (or D† ψ) with a JuliaQCD operator `D` on arrays, through the work fields `x`, `y`."
function apply_juliaqcd(D, x, y, ψ; dagger=false)
    set_fermion!(x, ψ)
    mul!(y, dagger ? D' : D, x)
    return get_fermion(y)
end

"""
    meson_measurement(U; κ, cSW=0.0, bc=(1, 1, 1, -1), channels=MESON_CHANNELS,
                      momenta=[(0, 0, 0)], source=(1, 1, 1, 1), eps_CG=1e-20)

QCDMeasurements' connected local meson correlators from a point source at
`source`, along the last direction. `get_value(measure(m, U))` is a Dict from
channel name (Symbol) to a matrix indexed by Δt = 0, …, L₄ − 1 and momentum.
QCDMeasurements 1.0.1 accepts only the default phases (1, 1, 1, −1); others
stop with an AssertionError when measured.

`eps_CG` bounds the squared residual: the QCDMeasurements default 1e-14
leaves a true relative residual of about 1e-7. The default here, 1e-20,
gives about 1e-10. `solver_residual(m)` returns the worst true relative
residual of the last measurement.
"""
meson_measurement(U; κ, cSW=0.0, bc=(1, 1, 1, -1), channels=MESON_CHANNELS,
    momenta=[(0, 0, 0)], source=(1, 1, 1, 1), eps_CG=1e-20) =
    MesonCorrelatorMeasurement(U;
        fermiontype=cSW == 0 ? "Wilson" : "WilsonClover", κ, cSW,
        channels, momenta, correlation_axis=4, source_position=source,
        BoundaryCondition=collect(bc), eps_CG, MaxCGstep=10000,
        verbose_level=0)

"Worst true relative residual |D x − b|/|b| of the last solves of a meson measurement."
solver_residual(m) = maximum(d.true_relative_residual for d in get_solver_diagnostics(m))
