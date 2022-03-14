import Base.Libc: malloc, free, realloc
import Base: getindex, setindex!, firstindex, lastindex
using Test

mutable struct Buffer{T}
    addr::Ptr{T}
    size::Int
end

Buffer{T}(size::Int) where T = begin
    bytewidth = size * sizeof(T)
    ptr_alloc = malloc(bytewidth)
    ptr_alloc == C_NULL && throw("Memory Allocation Failed")
    buff = Buffer{T}(Ptr{T}(ptr_alloc), size)
    finalizer(buff) do b
        Base.Libc.free(b.addr)
    end
    return buff
end

setindex!(buff::Buffer{T}, obj::T, idx::Int) where T = begin
    @boundscheck idx <= buff.size || throw(BoundsError("Out of Bounds"))
    unsafe_store!(buff.addr, obj, idx)
end

getindex(buff::Buffer{T}, idx::Int) where T = begin
    @boundscheck idx <= buff.size || throw(BoundsError("Out of Bounds"))
    unsafe_load(buff.addr, idx)
end

firstindex(buff::Buffer) = 1
lastindex(buff::Buffer) = buff.size

@testset "BufferAccessTests" begin
    buff = Buffer{Float64}(16)
    @test buff.size == 16
    buff[6] = 3.14
    @test buff[6] == 3.14
    @test_throws BoundsError buff[17]
    @test_throws BoundsError buff[17] = buff[6]
end

resize!(buff::Buffer{T}, size::Int) where T = begin
    bytewidth = size * sizeof(T)
    addr = realloc(buff.addr, bytewidth)
    addr == C_NULL && throw("Failed to reallocate memory buffer")
    buff.size = size
    buff.addr = Ptr{T}(addr)
end

@testset "BufferResizeTests" begin
    Point = Tuple{Float64, Float64, Float64}
    buff = Buffer{Point}(4)
    resize!(buff, 8)
    @test buff.size == 8
    @test_throws BoundsError buff[9]
    @test typeof(buff[8]) == Point
    resize!(buff, 4)
    @test_throws BoundsError buff[8]
end

copy!(src::Buffer{T},
      dest::Buffer{T},
      idxsrc::Int,
      idxdest::Int,
      size::Int) where T = begin
    idxsrcend = idxsrc + size - 1
    idxdestend = idxdest + size - 1
    @boundscheck idxsrcend <= src.size || throw(BoundsError())
    @boundscheck idxdestend <= dest.size || throw(BoundsError())
    while idxsrc <= idxsrcend
        dest[idxdest] = src[idxsrc]
        idxdest += 1
        idxsrc += 1
    end
end

@testset "BufferCopyTests" begin
    buff1 = Buffer{Int}(3)
    buff2 = Buffer{Int}(4)
    foreach(i -> buff1[i] = i, 1:3)
    foreach(i -> buff2[i] = 0, 1:4)
    copy!(buff1, buff2, 2, 3, 2)
    @test (buff2[1] == 0 &&
           buff2[2] == 0 &&
           buff2[3] == 2 &&
           buff2[4] == 3)
end

mutable struct MyArray{T, N} <: AbstractArray{T, N}
    data::Buffer{T}
    shape::NTuple{N, Int}
    offset::Int
end

MyVector{T} = MyArray{T, 1}

# construct an empty vector
MyVector{T}() where T = MyVector{T}(Buffer{T}(0), (0,))

# Queue interface
import Base: pop!, push!

pop!(v::MyVector{T}) where T = begin
    @boundscheck v.shape[0] > 0 || throw(BoundsError())
    idxbuff = v.shape[0] + v.offset - 1
    idxbuff = idxbuff - v.data.size * (idxbuff > v.data.size)
    v.shape[0] -= 1
    v.data[idxbuff]
end
push!(v::MyVector{T}, val::T) where T = begin
    (v.shape[0] < v.data.size) || resize!(v.data, 2 * v.data.size + 1)
    idxbuff = v.shape[0] + v.offset - 1
    idxbuff = idxbuff - v.data.size * (idxbuff > v.data.size)
    @inbounds v.data[idxbuff] = val
    v.shape[0] += 1
end
