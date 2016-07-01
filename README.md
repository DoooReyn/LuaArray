# LuaArray
较为严格的 Lua 数组的实现

## 说点什么
由于 `Lua` `table` 的特殊构造，使用纯 `Lua` 实现 **纯数组** 是很困难的—— `table` 是 `Array` 和 `HashMap` 的混合体， 二者合二为一，你中有我，我中有你，水乳交融，难以切分。因此， `Array` 很容易被污染而丧失 `Array` 的特性，`HashMap` 亦然。

但 `table` 还有一个奇妙的特性——**元表**，借助 **元表** 的特殊运用，我们可以实现一个比较严格的数组 `Array`。

## 基本要求
1. 不可以存在非整数的索引；
2. 可通过索引直接访问元素；
3. 传入元素可直接创建一个数组，不传默认为空数组；
4. 不允许数组索引越界；
5. 提供插入、移除、修改数组元素等基本操作数组的方法 *(有需要的话，可以按需求增加数组操作的方法，这里主要提供的是实现机制和思想)*；
6. 数组索引自动管理。

## 硬性约束
1. 不允许直接通过索引修改元素内容，也就是如下形式的赋值是不允许的：
    `arr[1] = 10;`  
    这是因为对索引元素设置`nil` 的话，数组的索引会被破坏；
2. 为了秉承 `Lua` 的习惯，第一个元素的索引为 `1`。

## 实现

### 还是 table
首先，我们创建一个函数:   
``` lua
function Array(...)
    local __array__ = {...}
    -- do something to construct an array
end
```
通过 `Array()` 来构造一个数组，其中 `...` 是传入的元素参数，`__array__` 用来存储数组元素。  
嗯哼，目前看来，`__array__` 可不还是一个`table`吗，其实还是什么都没有做呀。  
别急，接下来，重头戏就来了。

### 变异的 table
为了构造一个严格的数组，我们首要的问题就是保证 `__array__` 存储的都是整数的索引，这就要求我们就不能直接对 `__array__` 进行操作，而要对它进行特殊保护——**对外隐藏**：  
``` lua
function Array(...)
    local new_array = {}

    local __array__ = {...}

    local mt = {__index = new_array}
    setmetatable(new_array, mt)

    return new_array
end
```
为了实现隐藏的目的，我们增加了一个新的变量 `new_array`，让其元表指向 `__array__`，这样就可以直接通过索引访问数组元素，而又达到了隐藏真实数组的目的。  
但这样还有两个严重的安全隐患：
1. 通过 `getmetatable(new_array).__index` 依然可以获得真实的数组数据；
2. 最终返回的构造数组将是 `new_array`，那么 `new_array` 必须具备数组的基本特性。  

针对第一个问题，我们可以将`__index` 改为函数，实现彻底隐藏 `__array__`的目的：
``` lua
function Array(...)
    local new_array = {}

    local __array__ = {...}

    local mt = {
        __index = function(t, k)
            return __array__[k]
        end
    }
    setmetatable(new_array, mt)

    return new_array
end
```  

现在我们来看第二个问题，`new_array` 将作为外交官，完成对真实数组 `__array__` 的内部操作，那么 `new_array` 就必须看起来像真实的数组。为了保证 `new_array` 的纯净，我们必须再次改造它的元表。  
``` lua
function Array(...)
    local new_array = {}

    local __array__ = {...}

    local mt = {
        __index = function(t, k)
            return __array__[k]
        end,
        __newindex = function(t, k, v)
            if nil == __array__[k] then
                print(string.format('warning : [%s] index out of range.', tostring(k)))
                return
            end
            if nil == v then
                print(string.format('warning : can not remove element by using  `nil`.'))
                return
            end
            __array__[k] = v
        end
    }
    setmetatable(new_array, mt)

    return new_array
end
```
我们对元表增加了 `__newindex` 的属性，它控制着对 `new_array` 的内部元素的附带副作用的操作。可以看出，目前我们只允许 `new_array` 修改 `__array__` 已存在的元素的值 *(且不允许对直接对元素设值为 `nil`，原因我们在 **硬性约束** 中说过了)*，也就是所有与 `__array__` 无关的操作都被过滤了。
到目前为止，`new_array` 已经是一个较为严格的 **数组** 了，下面就要对这个 **数组** 进行扩展了，毕竟，除了能够对已存在的元素进行赋值操作，现在的这个 **数组** 什么都做不了。


### 扩展 Array
为了扩展 `Array` 的操作属性，必须添加额外的方法对 `__array__` 进行操作，我们像构造 `__array__` 一样，创建一个变量 `__methods__` 用来保存方法列表，同样，为了能够访问到 `methods` 中的方法，我们必须在元表中的 `__index` 添加 `__methods__` 的访问途径 *(在 web 中，这个概念是叫路由吧)*：

``` lua
function Array(...)
    local new_array = {}

    local __array__ = {...}

    local __methods__ = {}
    function __methods__:insert(v, at)
        local len = #__array__ + 1
        at = type(at) == 'number' and at or len
        at = math.min(at, len)
        table.insert(__array__, at, v)
    end
    function __methods__:removeAt(at)
        at = type(at) == 'number' and at or #__array__
        table.remove(__array__, at)
    end
    function __methods__:print()
        print('---> array content begin  <---')
        for i, v in ipairs(__array__) do
            print(string.format('[%s] => ', i), v)
        end
        print('---> array content end  <---')
    end

    -- extend methods here

    local mt = {
        __index = function(t, k)
            if __array__[k] then
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
                print(string.format('warning : can not remove element by using  `nil`.'))
                return
            end
            __array__[k] = v
        end
    }
    setmetatable(new_array, mt)

    return new_array
end
```

这里，为了方便展示，仅写了增、删两种方法，更多的还需要读者自己补充。我们来做一些 [测试](http://www.shucunwang.com/RunCode/lua/#id/46b7c5317f1bce33e82dfbcdbb23755a)：
``` lua
local arr = Array(1,2,3)
print(arr[1])   -- 1
print(arr[4])   -- nil
arr[1] = 4
arr:print()     -- 4,3,2
arr[4] = 'a'    -- warning : [4] index out of range.
arr[2] = nil    -- warning : can not remove element by using  `nil`.
arr:insert('a')
arr:insert('b', 2)
arr:print()     -- 4,b,2,3,a
arr:removeAt(1)
arr:print()     -- b,2,3,a
```

好了，现在一个较为严格的数组已经完成了，怎么用，就看大家的意愿了。

PS: 借助同样的机制，我们可以实现一个纯 `HashMap`，懒得动，就不写教程了吧。

