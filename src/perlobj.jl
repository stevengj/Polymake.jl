function perlobj(name::String, input_data::Dict{<:Union{String, Symbol},T}) where T
    perl_obj = pm_perl_Object(name)
    for value in input_data
        key = string(value[1])
        val = convert(PolymakeType, value[2])
        take(perl_obj,key,val)
    end
    return perl_obj
end

function perlobj(name::String, input_data::Pair{<:Union{Symbol,String}}...; kwargsdata...)
    obj = pm_perl_Object(name)
    for (key, val) in input_data
        setproperty!(obj, string(key), val)
    end
    for (key, val) in kwargsdata
        setproperty!(obj, string(key), val)
    end
    return obj
end

Base.propertynames(p::Polymake.pm_perl_Object) = Symbol.(Polymake.complete_property(p, ""))

function Base.setproperty!(obj::pm_perl_Object, prop::String, val)
    return take(obj, prop, convert(PolymakeType, val))
end

function Base.setproperty!(obj::pm_perl_Object, prop::Symbol, val)
    return take(obj, string(prop), convert(PolymakeType, val))
end

function give(obj::Polymake.pm_perl_Object, prop::String)
    return_obj = try
        internal_give(obj, prop)
    catch ex
        throw(PolymakeError(ex.msg))
    end
    return convert_from_property_value(return_obj)
end

Base.getproperty(obj::pm_perl_Object, prop::Symbol) = give(obj, string(prop))

function complete_property(obj::pm_perl_Object, prefix::String)
   call_function(:common, :complete_property, obj, prefix)
end

function convert_from_property_value(obj::Polymake.pm_perl_PropertyValue)
    type_name = Polymake.typeinfo_string(obj,true)
    T = Symbol(replace(type_name," "=>""))
    if haskey(TypeConversionFunctions, T)
        f = TypeConversionFunctions[T]
        return f(obj)
    elseif startswith(type_name,"Visual::")
        return Visual(obj)
    else
        return obj
    end
end

function pm_perl_OptionSet(iter)
    opt_set = pm_perl_OptionSet()
    for (key, value) in iter
        option_set_take(opt_set, string(key), value)
    end
    return opt_set
end