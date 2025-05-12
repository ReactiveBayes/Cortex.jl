@testitem "resolve_dependencies! must resolve all variables and factors in the model" setup = [ModelUtils] begin
    import Cortex: add_variable_to_model!, add_factor_to_model!, add_edge_to_model!

    struct CustomDependencyResolver <: AbstractDependencyResolver 
        resolved::Set{Any}
    end

    model = Model()

    x = add_variable_to_model!(model, :x)
    y = add_variable_to_model!(model, :y)
    z = add_variable_to_model!(model, :z)

    f1 = add_factor_to_model!(model, :f1)
    f2 = add_factor_to_model!(model, :f2)

    resolve_dependencies!(model)

    @test get_variable_dependencies(model, x) == [f1]
    
    return model

end