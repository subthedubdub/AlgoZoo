import Base.Libc: malloc, free, realloc
import Base: getindex, setindex!, firstindex, lastindex
using Test

mutable struct DataBuffer{T}
    addr::Ptr{T}
    size::Int
end

DataBuffer{T}(size::Int) where T = begin
    bytewidth = size * sizeof(T)
    ptr_alloc = malloc(bytewidth)
    ptr_alloc == C_NULL && throw("Memory Allocation Failed")
    buff = DataBuffer{T}(Ptr{T}(ptr_alloc), size)
    finalizer(buff) do b
        Base.Libc.free(b.addr)
    end
    return buff
end

setindex!(buff::DataBuffer{T}, obj::T, idx::Int) where T = begin
    @boundscheck idx <= buff.size || throw(BoundsError("Out of Bounds"))
    unsafe_store!(buff.addr, obj, idx)
end

getindex(buff::DataBuffer{T}, idx::Int) where T = begin
    @boundscheck idx <= buff.size || throw(BoundsError("Out of Bounds"))
    unsafe_load(buff.addr, idx)
end

firstindex(buff::DataBuffer) = 1
lastindex(buff::DataBuffer) = buff.size

@testset "BufferAccessTests" begin
    buff = DataBuffer{Float64}(16)
    @test buff.size == 16
    buff[6] = 3.14
    @test buff[6] == 3.14
    @test_throws BoundsError buff[17]
    @test_throws BoundsError buff[17] = buff[6]
end

resize!(buff::DataBuffer{T}, size::Int) where T = begin
    bytewidth = size * sizeof(T)
    addr = realloc(buff.addr, bytewidth)
    addr == C_NULL && throw("Failed to reallocate memory buffer")
    buff.size = size
    buff.addr = Ptr{T}(addr)
end

@testset "BufferResizeTests" begin
    Point = Tuple{Float64, Float64, Float64}
    buff = DataBuffer{Point}(4)
    resize!(buff, 8)
    @test buff.size == 8
    @test_throws BoundsError buff[9]
    @test typeof(buff[8]) == Point
    resize!(buff, 4)
    @test_throws BoundsError buff[8]
end

copy!(src,
      dest::DataBuffer{T},
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
    buff1 = DataBuffer{Int}(3)
    buff2 = DataBuffer{Int}(4)
    foreach(i -> buff1[i] = i, 1:3)
    foreach(i -> buff2[i] = 0, 1:4)
    copy!(buff1, buff2, 2, 3, 2)
    @test (buff2[1] == 0 &&
           buff2[2] == 0 &&
           buff2[3] == 2 &&
           buff2[4] == 3)
end

mutable struct ViewBuffer{T}
    dat::DataBuffer{T}
    offset::Int
    size::Int
end

setindex!(buff::ViewBuffer{T}, obj::T, idx::Int) where T = begin
    @boundscheck idx <= buff.size || throw(BoundsError())
    @boundscheck buff.offset + idx - 1 <= buff.dat.size || throw(BoundsError())
    @inbounds buff.dat[buff.offset + idx - 1] = obj
end

getindex(buff::ViewBuffer{T}, idx::Int) where T = begin
    @boundscheck idx <= buff.size || throw(BoundsError())
    @boundscheck buff.offset + idx - 1 <= buff.dat.size || throw(BoundsError())
    @inbounds buff.dat[buff.offset + idx - 1]
end

firstindex(buff::ViewBuffer) = 1
lastindex(buff::ViewBuffer) = buff.size
