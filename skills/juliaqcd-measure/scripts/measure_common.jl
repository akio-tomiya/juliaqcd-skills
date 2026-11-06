# Measurement helpers on JuliaQCD gauge fields. Load after Gaugefields.

include(joinpath(@__DIR__, "..", "..", "juliaqcd-generate", "scripts", "common.jl"))
using QCDMeasurements
using Wilsonloop
using LinearAlgebra

"""
    WilsonLoops(U, Rmax, Tmax)

Wilson loops W(R, T), R steps in each spatial direction μ < d and T steps in
the last direction d, built from `Wilsonline` and `evaluate_gaugelinks!`.
Works in any dimension. (QCDMeasurements' `WilsonLoopMeasurement` covers
four dimensions only: in two and three dimensions its constructor throws.)
"""
struct WilsonLoops{TG,TL}
    Rmax::Int
    Tmax::Int
    loops::TL
    work::TG
    temps::Vector{TG}
end

function WilsonLoops(U, Rmax, Tmax)
    d = length(U)
    loops = [[[Wilsonline([(μ, R), (d, T), (μ, -R), (d, -T)], Dim=d)] for μ in 1:d-1]
             for R in 1:Rmax, T in 1:Tmax]
    work = similar(U[1])
    temps = [similar(U[1]) for _ in 1:4]
    return WilsonLoops(Rmax, Tmax, loops, work, temps)
end

"Matrix of W(R, T), rows R = 1:Rmax, columns T = 1:Tmax, normalized to 1 on a cold field."
function measure_wilson_loops(m::WilsonLoops, U)
    d = length(U)
    n = gauge_num_colors(U)
    V = prod(size(U[1])[3:end])
    W = zeros(m.Rmax, m.Tmax)
    for R in 1:m.Rmax, T in 1:m.Tmax
        s = 0.0
        for μ in 1:d-1
            evaluate_gaugelinks!(m.work, m.loops[R, T][μ], U, m.temps)
            s += real(tr(m.work))
        end
        W[R, T] = s / (n * V * (d - 1))
    end
    return W
end

"""
    FlowMeasurement(U; step_size, steps, every)

Wilson flow of a copy of the field with Lüscher's RK3 integrator, measured
every `every` steps from t = 0 to t = steps × step_size. Records the
plaquette form of the energy density in any dimension; in four dimensions
also the clover form and the topological charge (clover, and the improved
definition of QCDMeasurements), through `GradientFlowScaleMeasurement`.
The input field is not changed.
"""
struct FlowMeasurement{TU,TF,TM}
    d::Int
    step_size::Float64
    steps::Int
    every::Int
    Uflow::TU
    flow::TF
    measurement::TM
end

function FlowMeasurement(U; step_size, steps, every)
    steps % every == 0 || throw(ArgumentError("steps ($steps) must be a multiple of every ($every)"))
    d = length(U)
    if d == 4
        m = GradientFlowScaleMeasurement(U; flow_step_size=step_size,
            number_of_flow_steps=steps, flow_measure_every=every,
            energy_methods=["plaquette", "clover"], measure_topological_charge=true,
            topological_charge_methods=["clover"],
            improved_topological_charge_definition="alexandrou")
        return FlowMeasurement(d, Float64(step_size), steps, every, nothing, nothing, m)
    end
    Uflow = copy_configuration(U)
    flow = gradient_flow(Uflow; steps=every, step_size=step_size)
    return FlowMeasurement(d, Float64(step_size), steps, every, Uflow, flow, nothing)
end

"""
    measure_flow(m, U)

Named tuple of vectors over the flow times: `t`, `E_plaq`, and in four
dimensions `E_clover`, `Q_clover`, `Q_improved`.
"""
function measure_flow(m::FlowMeasurement, U)
    if m.d == 4
        h = get_value(measure(m.measurement, U))
        return (t=h.flow_time, E_plaq=h.energy_density["plaquette"],
            E_clover=h.energy_density["clover"],
            Q_clover=h.topological_charge["clover"],
            Q_improved=h.topological_charge["clover improved"])
    end
    copy_configuration!(m.Uflow, U)
    planes = m.d * (m.d - 1) ÷ 2
    n = gauge_num_colors(U)
    t = Float64[]
    E = Float64[]
    k = 0
    while true
        push!(t, k * m.step_size)
        push!(E, 2 * n * planes * (1 - measure_plaquette(m.Uflow)))
        k + m.every <= m.steps || break
        flow!(m.Uflow, m.flow)
        k += m.every
    end
    return (t=t, E_plaq=E)
end

"""
    set_links!(U, links, path)

Load host link arrays into the field `U` by writing a portable JLD2 file at
`path` (the metadata is taken from `U`) and reading it back.
"""
function set_links!(U, links, path)
    save_configuration(path, U)
    data = JLD2.load(path)
    data["links"] = links
    JLD2.jldopen(path, "w") do f
        for (k, v) in data
            f[k] = v
        end
    end
    load_configuration!(U, path)
    return U
end
