# const VcDict{S,T<:AbstractVarConstr} = PerIdDict{S,T}
# const VarDict = VcDict{VarState,Variable}
# const ConstrDict = VcDict{ConstrState,Constraint}

mutable struct Formulation{Duty <: AbstractFormDuty}  <: AbstractFormulation
    uid::FormId
    problem::AbstractProblem # Should be removed. Only kept here because of counters
    parent_formulation::Union{AbstractFormulation, Nothing} # master for sp, reformulation for master
    #moi_model::Union{MOI.ProblemLike, Nothing}
    moi_optimizer::Union{MOI.AbstractOptimizer, Nothing}
    manager::FormulationManager
    obj_sense::ObjSense
    primal_inc_bound::Float64
    dual_inc_bound::Float64
    primal_solution_record::Union{PrimalSolution, Nothing}
    dual_solution_record::Union{DualSolution, Nothing}
    callback
end

function Formulation{D}(p::AbstractProblem;
                        parent_formulation = nothing,
                        obj_sense::ObjSense = Min,
                        primal_inc_bound::Float64 = Inf,
                        dual_inc_bound::Float64 = -Inf
                        ) where {D<:AbstractFormDuty}
    return Formulation{D}(
        getnewuid(p.form_counter), p, parent_formulation, nothing,
        FormulationManager(),
        obj_sense, primal_inc_bound, dual_inc_bound, nothing,
        nothing, nothing
    )
end

get_var(f::Formulation, id::VarId) = get_var(f.manager, id)

get_constr(f::Formulation, id::ConstrId) = get_constr(f.manager, id)

get_vars(f::Formulation) = get_vars(f.manager)

get_constrs(f::Formulation) = get_constrs(f.manager)

get_coefficient_matrix(f::Formulation) = get_coefficient_matrix(f.manager)

getuid(f::Formulation) = f.uid

getobjsense(f::Formulation) = f.obj_sense


function generatevarid(f::Formulation)
    return VarId(getnewuid(f.problem.var_counter))
end

function generateconstrid(f::Formulation)
    return ConstrId(getnewuid(f.problem.constr_counter))
end

function set_var!(f::Formulation,
                  name::String,
                  duty::Type{<:AbstractVarDuty};
                  cost::Float64 = 0.0,
                  lb::Float64 = 0.0,
                  ub::Float64 = Inf,
                  kind::VarKind = Continuous,
                  sense::VarSense = Positive,
                  moi_index::MoiVarIndex = MoiVarIndex())
    id = generatevarid(f)
    v_data = VarData(cost, lb, ub, kind, sense, true)
    v = Variable(id, name, duty; var_data = v_data, moi_index = moi_index)
    add_var!(f.manager, v)
    return v
end

function add_var!(f::Formulation,
                  name::String,
                  duty::Type{<:AbstractVarDuty};
                  cost::Float64 = 0.0,
                  lb::Float64 = 0.0,
                  ub::Float64 = Inf,
                  kind::VarKind = Continuous,
                  sense::VarSense = Positive,
                  moi_index::MoiVarIndex = MoiVarIndex())
    id = generatevarid(f)
    v_data = VarData(cost, lb, ub, kind, sense, true)
    v = Variable(id, name, duty; var_data = v_data, moi_index = moi_index)
    add_var!(f.manager, v)
    return v
end

function add_constr!(f::Formulation,
                     name::String,
                     duty::Type{<:AbstractConstrDuty};
                     rhs::Float64 = 0.0,
                     kind::ConstrKind = 0.0,
                     sense::ConstrSense = 0.0,
                     moi_index::MoiConstrIndex = MoiConstrIndex())
    id = generateconstrid(f)
    c_data = ConstrData(rhs, kind, sense, true)
    c = Constraint(id, name, duty; constr_data = c_data, moi_index = moi_index)
    add_constr!(f.manager, c)
    return c
end

function register_objective_sense!(f::Formulation, min::Bool)
    !min && error("Coluna does not support maximization yet.")
    return
end

function _show_obj_fun(io::IO, f::Formulation)
    print(io, getobjsense(f), " ")
    for (id, var) in filter(_explicit_, getvars(f))
        name = getname(var)
        cost = getcost(get_cur_data(var))
        op = (cost < 0.0) ? "-" : "+" 
        print(io, op, " ", abs(cost), " ", name, " ")
    end
    println(io, " ")
    return
end

function _show_constraint(io::IO, f::Formulation, constr_id::ConstrId,
                          members::MembersVector{VarId,Variable,Float64})
    constr = getconstr(f, constr_id)
    constr_data = get_cur_data(constr)
    print(io, constr_id, " ", getname(constr), " : ")
    for (var_id, coeff) in members
        var = getvar(f, var_id)
        name = getname(var)
        op = (coeff < 0.0) ? "-" : "+"
        print(io, op, " ", abs(coeff), " ", name, " ")
    end
    if getsense(constr_data) == Equal
        op = "=="
    elseif getsense(constr_data) == Greater
        op = ">="
    else
        op = "<="
    end
    print(io, " ", op, " ", getrhs(constr_data))
    println(io, " (", getduty(constr) ,")")
    return
end

function _show_constraints(io::IO , f::Formulation)
    constrs = filter(
        x->(getduty(x) isa ExplicitDuty), rows(get_members_matrix(f))
    )
    for (constr_id, members) in constrs
        _show_constraint(io, f, constr_id, members)
    end
    return
end

function _show_variable(io::IO, f::Formulation, var::Variable)
    var_data = get_cur_data(var)
    name = getname(var)
    lb = getlb(var_data)
    ub = getub(var_data)
    t = getkind(var_data)
    d = getduty(var)
    println(io, getid(var), " ", lb, " <= ", name, " <= ", ub, " (", t, " | ", d , ")")
end

function _show_variables(io::IO, f::Formulation)
    for (id, var) in filter(_explicit_, getvars(f))
        _show_variable(io, f, var)
    end
end

function Base.show(io::IO, f::Formulation)
    println(io, "Formulation id = ", getuid(f))
    _show_obj_fun(io, f)
    _show_constraints(io, f)
    _show_variables(io, f)
    return
end

##################################################################
# function Formulation(Duty::Type{<: AbstractFormDuty},
#                      m::AbstractProblem, 
#                      parent_formulation::Union{AbstractFormulation, Nothing},
#                      moi_optimizer::Union{MOI.AbstractOptimizer, Nothing})
#     uid = getnewuid(m.form_counter)
#     return Formulation{Duty}(uid,
#                              m,
#                              parent_formulation,
#                              #moi_model,
#                              moi_optimizer, 
#                              VarDict(),
#                              ConstrDict(),
#                              Memberships(),
#                              Min,
#                              nothing,
#                              Inf,
#                              -Inf,
#                              nothing,
#                              nothing)
# end

# function Formulation(Duty::Type{<: AbstractFormDuty},
#                      m::AbstractProblem, 
#                      optimizer::Union{MOI.AbstractOptimizer, Nothing})
#     return Formulation(Duty, m, nothing, optimizer)
# end

# function Formulation(Duty::Type{<: AbstractFormDuty}, m::AbstractProblem, 
#                      parent_formulation::Union{AbstractFormulation, Nothing})
#     return Formulation(Duty, m, parent_formulation, nothing)
# end

# function Formulation(Duty::Type{<: AbstractFormDuty}, m::AbstractProblem)
#     return Formulation(Duty, m, nothing, nothing)
# end

# #getvarcost(f::Formulation, uid) = f.costs[uid]
# #getvarlb(f::Formulation, uid) = f.lower_bounds[uid]
# #getvarub(f::Formulation, uid) = f.upper_bounds[uid]

# #getconstrrhs(f::Formulation, uid) = f.rhs[uid]
# #getconstrsense(f::Formulation, uid) = f.constr_senses[uid]

# get_memberships(f::Formulation) = f.memberships

# get_varid_from_uid(f::Formulation, uid::Int) = getkey(f.manager.vars, Id{VarState}(uid), Id{VarState}())
# get_constrid_from_uid(f::Formulation, uid::Int) = getkey(f.mamanger.constrs, Id{ConstrState}(uid), Id{ConstrState}())


# getvar_ids(fo::Formulation, fu::Function) = filter(fu, fo.vars)

# getconstr_ids(fo::Formulation, fu::Function) = filter(fu, fo.constrs)


# getvar(f::Formulation, id::Id{VarState}) = get(f, id)
# getconstr(f::Formulation, id::Id{ConstrState}) = get(f, id)
# getstate(f::Formulation, id::Id{VarState}) = getstate(getkey(f.manager.vars, id, 0)) # TODO change the default value (empty Id)
# getstate(f::Formulation, id::Id{ConstrState}) = getstate(getkey(f.mamanger.constrs, id, 0))

# has(f::Formulation, id::Id{VarState}) = haskey(f.manager.vars, id)
# has(f::Formulation, id::Id{ConstrState}) = haskey(f.mamanger.constrs, id)
# get(f::Formulation, id::Id{VarState}) = f.manager.vars[id]
# get(f::Formulation, id::Id{ConstrState}) = f.mamanger.constrs[id]

# @deprecate getvar get
# @deprecate getconstr get

# getvar_ids(f::Formulation) = getids(f.manager.vars)

# getconstr_ids(f::Formulation) = getids(f.mamanger.constrs)


# #getvar_ids(f::Formulation, Duty::Type{<:AbstractVarDuty}) = collect(keys(get_subset(f.manager.vars, Duty)))

# #getconstr_ids(f::Formulation, Duty::Type{<:AbstractVarDuty}) = collect(keys(get_subset(f.manager.vars, Duty)))

# #getvar_ids(f::Formulation, Duty::Type{<:AbstractVarDuty}, stat::Status) = collect(keys(get_subset(f.manager.vars, Duty, stat)))

# #getconstr_ids(f::Formulation, Duty::Type{<:AbstractVarDuty}, stat::Status) = collect(keys(get_subset(f.manager.vars, Duty, stat)))

# #getvar_ids(f::Formulation, stat::Status) = collect(keys(get_subset(f.manager.vars, stat)))

# #getconstr_ids(f::Formulation,  stat::Status) = collect(keys(get_subset(f.manager.vars, stat)))


# get_constr_members_of_var(f::Formulation, id::Id) = get_constr_members_of_var(f.memberships, id)

# get_var_members_of_constr(f::Formulation, id::Id) = get_var_members_of_constr(f.memberships, id)

# #TODO membership should be an optional arg
# # TODO membership should be an optional arg
# function add!(f::Formulation, var::Variable, id::Id{VarState})
#     f.manager.vars[id] = var
#     set_variable!(f.memberships, id) 
#     return id
# end

# function add!(f::Formulation, var::Variable, id::Id{VarState}, 
#         membership::ConstrMemberDict)
#     f.manager.vars[id] = var
#     set_variable!(f.memberships, id, membership)
#     return id
# end

# function add!(f::Formulation, constr::Constraint, id::Id{ConstrState})
#     f.mamanger.constrs[id] = constr
#     set_constraint!(f.memberships, id)
#     return id
# end

# function add!(f::Formulation, constr::Constraint, id::Id{ConstrState},
#        membership::VarMemberDict)
#     f.mamanger.constrs[id] = constr
#     set_constraint!(f.memberships, id, membership)
#     return id
# end

# function add!(f::Formulation, var::Variable, Duty::Type{<: AbstractVarDuty})
#     uid = getnewuid(f.problem.var_counter)
#     id = Id(uid, VarState(Duty, var))
#     add!(f, var, id)
#     return id
# end

# function add!(f::Formulation, var::Variable, Duty::Type{<: AbstractVarDuty}, 
#         membership::ConstrMemberDict)
#     uid = getnewuid(f.problem.var_counter)
#     id = Id(uid, VarState(Duty, var))
#     add!(f, var, id, membership)
#     return id
# end

# function add!(f::Formulation, constr::Constraint, 
#         Duty::Type{<: AbstractConstrDuty})
#     uid = getnewuid(f.problem.constr_counter)
#     id = Id(uid, ConstrState(Duty, constr))
#     add!(f, constr, id)
#     return id
# end

# function add!(f::Formulation, constr::Constraint, 
#         Duty::Type{<: AbstractConstrDuty}, membership::VarMemberDict)
#     uid = getnewuid(f.problem.constr_counter)
#     id = Id(uid, ConstrState(Duty, constr))
#     add!(f, constr, id, membership)
#     return id
# end

# function register_objective_sense!(f::Formulation, min::Bool)
#     # if !min
#     #     m.obj_sense = Max
#     #     m.costs *= -1.0
#     # end
#     !min && error("Coluna does not support maximization yet.")
#     return
# end

# # function optimize(form::Formulation, oracle::Any)
# #     setup(oracle, form.orcale_info)
# #     optimize(oracle)
# # end

# function optimize(form::Formulation, optimizer = form.moi_optimizer,
#                   update_form = true)
#     call_moi_optimize_with_silence(form.moi_optimizer)
#     status = MOI.get(form.moi_optimizer, MOI.TerminationStatus())
#     primal_sols = PrimalSolution[]
#     @logmsg LogLevel(-4) string("Optimization finished with status: ", status)
#     if MOI.get(optimizer, MOI.ResultCount()) >= 1
#         primal_sol = retrieve_primal_sol(form, filter(_explicit_ , form.vars))
#         push!(primal_sols, primal_sol)
#         dual_sol = retrieve_dual_sol(form, filter(_active_ , form.constrs))
#         if update_form
#             form.primal_solution_record = primal_sol
#             if dual_sol != nothing
#                 form.dual_solution_record = dual_sol
#             end
#         end
#         return (status, primal_sol.value, primal_sols, dual_sol)
#     end
#     @logmsg LogLevel(-4) string("Solver has no result to show.")
#     return (status, Inf, nothing, nothing)
# end

# function compute_original_cost(sol::PrimalSolution, form::Formulation)
#     cost = 0.0
#     for (var_uid, val) in sol.members
#         var = getvar(form, var_uid)
#         cost += var.cost * val
#     end
#     @logmsg LogLevel(-4) string("intrinsic_cost = ",cost)
#     return cost
# end

# function _show_obj_fun(io::IO, f::Formulation)
#     print(io, getobjsense(f), " ")
#     for id in keys(filter(_explicit_, getvars(f)))
#         var = getvar(f, id)
#         name = getname(var)
#         cost = getcost(getstate(id))
#         op = (cost < 0.0) ? "-" : "+" 
#         #if cost != 0.0
#             print(io, op, " ", abs(cost), " ", name, " ")
#         #end
#     end
#     println(io, " ")
#     return
# end

# function _show_constraint(io::IO, f::Formulation, id)
#     constr = getconstr(f, id)
#     constrinfo = getstate(id)
#     print(io, id, " ", getname(constr), " : ")
#     membership = get_var_members_of_constr(f, id)
#     var_ids = keys(filter(_explicit_, membership))
#     for var_id in var_ids 
#         coeff = membership[var_id]
#         if haskey(f.manager.vars, var_id)
#             var = getvar(f, var_id)
#             name = getname(var)
#             op = (coeff < 0.0) ? "-" : "+"
#             print(io, op, " ", abs(coeff), " ", name, " ")
#         else
#             @warn "Cannot find variable with id $var_id and coeff $coeff which is member of constraint $(getname(constr))"
#         end
#     end

#     if getsense(constr) == Equal
#         op = "=="
#     elseif getsense(constr) == Greater
#         op = ">="
#     else
#         op = "<="
#     end
#     print(io, " ", op, " ", getrhs(getstate(id)))
#     d = getduty(constrinfo)
#     println(io, " (", d ,")")
#     return
# end

# function _show_constraints(io::IO , f::Formulation)
#     for id in keys(filter(_explicit_, getconstrs(f))) #sort!(keys(filter(_explicit_, getconstrs(f))))
#         _show_constraint(io, f, id)
#     end
#     return
# end

# function _show_variable(io::IO, f::Formulation, id)
#     var = getvar(f, id)
#     var_state = getstate(id)
#     name = getname(var)
#     lb = getlb(var_state)
#     ub = getub(var_state)
#     t = getkind(var)
#     d = getduty(var_state)
#     println(io, id, " ", lb, " <= ", name, " <= ", ub, " (", t, " | ", d , ")")
# end

# function _show_variables(io::IO, f::Formulation)
#     for id in  keys(filter(_explicit_, getvars(f)))
#         #sort!(keys(filter(_explicit_, getvars(f))))
#         _show_variable(io, f, id)
#     end
# end

# function Base.show(io::IO, f::Formulation)
#     println(io, "Formulation id = ", getuid(f))
#     _show_obj_fun(io, f)
#     _show_constraints(io, f)
#     _show_variables(io, f)
#     return
# end

# function load_problem_in_optimizer(formulation::Formulation)
#     for (id, var) in filter(_explicit_, getvars(formulation))
#         add_variable_in_optimizer(formulation.moi_optimizer, id)
#     end
#     for (id, constr) in filter(_active_, getconstrs(formulation))
#         add_constraint_in_optimizer(
#             formulation.moi_optimizer, id,
#             filter(_explicit_, get_var_members_of_constr(formulation, id))
#         )
#     end
# end

# function initialize_moi_optimizer(form::Formulation, factory::JuMP.OptimizerFactory)
#     form.moi_optimizer = create_moi_optimizer(factory)
# end

# function retrieve_primal_sol(form::Formulation,
#                              vars::VarDict)
#     new_sol = VarMemberDict()
#     new_obj_val = MOI.get(form.moi_optimizer, MOI.ObjectiveValue())
#     #error("Following line does not work.")
#     fill_primal_sol(form.moi_optimizer, new_sol, vars)
#     primal_sol = PrimalSolution(new_obj_val, new_sol)
#     @logmsg LogLevel(-4) string("Objective value: ", new_obj_val)
#     return primal_sol
# end

# function retrieve_dual_sol(form::Formulation,
#                            constrs::ConstrDict)
#     # TODO check if supported by solver
#     if MOI.get(form.moi_optimizer, MOI.DualStatus()) != MOI.FEASIBLE_POINT
#         println("dual status is : ", MOI.get(form.moi_optimizer, MOI.DualStatus()))
#         return nothing
#     end
#     new_sol = ConstrMemberDict()
#     obj_bound = MOI.get(form.moi_optimizer, MOI.ObjectiveBound())
#     fill_dual_sol(form.moi_optimizer, new_sol, constrs)
#     dual_sol = DualSolution(obj_bound, new_sol)
#     return dual_sol
# end

# function is_sol_integer(sol::PrimalSolution, tolerance::Float64)
#     for (var_id, var_val) in sol.members
#         if (!is_value_integer(var_val, tolerance)
#                 && (getkind(getstate(var_id)) == 'I' || getkind(getstate(var_id)) == 'B'))
#             @logmsg LogLevel(-2) "Sol is fractional."
#             return false
#         end
#     end
#     @logmsg LogLevel(-4) "Solution is integer!"
#     return true
# end


# function update_var_status(var_id::Id{VarState},
#                            new_status::Status)
#     @logmsg LogLevel(-2) "change var status "  getstatus(getstate(var_id)) == new_status var_id

#     setstatus!(getstate(var_id), new_status)
# end

# function update_constr_status(constr_id::Id{ConstrState},
#                               new_status::Status)
#     @logmsg LogLevel(-2) "change var status "  getstatus(getstate(constr_id)) == new_status constr_id

#     setstatus!(getstate(constr_id), new_status)
# end
