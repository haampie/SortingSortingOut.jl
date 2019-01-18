abstract type Ord end

using Base: tail

# Composable ordering objects

struct Op{F} <: Ord
    isless::F
end

struct Rev{O<:Ord} <: Ord
    isless::O
end

struct By{F,O<:Ord} <: Ord
    f::F
    isless::O
end

# Defaults
const Forward = Op(isless)
const Backward = Rev(Forward)
By(f) = By(f, Forward)

# Implementation of binary operators
@inline (o::Op)(a, b) = o.isless(a, b)
@inline (o::Rev)(a, b) = o.isless(b, a)
@inline (o::By)(a, b) = o.isless(o.f(a), o.f(b))

# Flattened way of writing the effective order s.t. it can be dispatched on
struct TrivialOrder{T,Op,Rev,F} <: Ord
    isless::Op
    fs::F

    TrivialOrder{T,R}(isless::Op, fs::F) where {T,Op,R,F} = new{T,Op,R,F}(isless, fs)
    TrivialOrder{T}(isless::Op, fs::F) where {T,Op,F} = new{T,Op,false,F}(isless, fs)
    TrivialOrder{T}(isless::Op) where {T,Op} = new{T,Op,false,Tuple{}}(isless, ())
end

# We need to be able to get the mapped value
@inline by(o::TrivialOrder, a) = by(o.fs, a)
@inline by(o::Tuple{}, a) = a
@inline by(o::Tuple{f}, a) where {f} = o[1](a)
@inline by(o::Tuple{f,g}, a) where {f,g} = o[1](o[2](a))
@inline by(o::Tuple, a) = first(o)(by(tail(o), a))

# TrivialOrder's implementation of comparison
@inline (o::TrivialOrder{T,Op,false})(a, b) where {T, Op} = o.isless(by(o, a), by(o, b))
@inline (o::TrivialOrder{T,Op,true})(a, b) where {T, Op} = o.isless(by(o, b), by(o, a))

# Flatten a given order
@inline flatten(o::Op{F}, ::Type{T}) where {F,T} = TrivialOrder{T}(o.isless)
@inline flatten(o::Union{Rev,By}, ::Type{T}) where {T} = merge(o, flatten(o.isless, T))
@inline flatten(o::Ord, ::Type{T}) where {T} = o

@inline function merge(o::By{F}, f::TrivialOrder{T,O,R,B}) where {F,T,O,R,B}
    newf = (o.f, f.fs...)
    ElT = Base._return_type(o.f, Tuple{T})
    TrivialOrder{ElT}(f.isless, newf)
end
@inline merge(o::Rev, f::TrivialOrder{T,O,R,B}) where {T,O,R,B} = TrivialOrder{T,!R}(f.isless, f.fs)
@inline merge(o::Ord, f) = o

### Skipping the transformation with `Value` wrapper

struct Value
    value
end

@inline (o::Op)(a::Value, b) = o.isless(a.value, b)
@inline (o::Op)(a, b::Value) = o.isless(a, b.value)
@inline (o::Op)(a::Value, b::Value) = o.isless(a.value, b.value)
@inline (o::By)(a::Value, b) = o.isless(a, o.f(b))
@inline (o::By)(a, b::Value) = o.isless(o.f(a), b)
@inline (o::By)(a::Value, b::Value) = o.isless(a, b)

@inline (o::TrivialOrder{T,Op,false})(a::Value, b) where {T, Op} = o.isless(a.value, by(o, b))
@inline (o::TrivialOrder{T,Op,false})(a, b::Value) where {T, Op} = o.isless(by(o, a), b.value)
@inline (o::TrivialOrder{T,Op,false})(a::Value, b::Value) where {T, Op} = o.isless(a.value, b.value)

@inline (o::TrivialOrder{T,Op,true})(a, b::Value) where {T, Op} = o.isless(b.value, by(o, a))
@inline (o::TrivialOrder{T,Op,true})(a::Value, b) where {T, Op} = o.isless(by(o, b), a.value)
@inline (o::TrivialOrder{T,Op,true})(a::Value, b::Value) where {T, Op} = o.isless(b.value, a.value)