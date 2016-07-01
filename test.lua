require('array')

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
