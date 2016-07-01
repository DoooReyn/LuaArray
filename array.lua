function isNumber(v)
    return type(v) == 'number'
end

function Array(...)
    local new_array = {}

    local __array__ = {...}

    local __methods__ = {}
    function __methods__:typeof()
        return 'Array'
    end
    function __methods__:insert(v, at)
        local len = #__array__ + 1
        at = isNumber(at) and at or len
        at = math.min(at, len)
        table.insert(__array__, at, v)
    end
    function __methods__:remove(at)
        at = isNumber(at) and at or #__array__
        table.remove(__array__, at)
    end
    function __methods__:print()
        table.print(__array__)
    end
    function __methods__:shift()
        return self:remove(1)
    end
    function __methods__:unshift(v)
        return self:insert(v, 1)
    end
    function __methods__:append(...)
        local elements = {...}
        for i= 1, #elements do
            self:insert(elements[i])
        end
    end

    local mt = {
        __index = function(t, k)
            if isNumber(k) then
                return __array__[k]
            end
            if __methods__[k] then
                return __methods__[k]
            end
        end,
        __newindex = function(t, k, v)
            if nil == __array__[k] then
                print(string.format('warning : [%s] index out of range.', tostring(k)))
                return
            end
            if nil == v then
                print(string.format('warning : can not set element to `nil` directly.'))
                return
            end
            __array__[k] = v
        end
    }
    setmetatable(new_array, mt)

    return new_array
end
