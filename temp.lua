    do
        -- Avoid heap allocs for performance
        local fcomp_default: function = function( a: nil,b: any ): any return a < b end
        function table_bininsert(t: table, value: number, fcomp): number
           -- Initialise compare function
           local fcomp: any = fcomp or fcomp_default
           --  Initialise numbers
           local iStart: number,iEnd: number,iMid: number,iState: number = 1,#t,1,0
           -- Get insert position
           while iStart <= iEnd do
              -- calculate middle
              iMid = math.floor( (iStart+iEnd)/2 )
              -- compare
              if fcomp( value,t[iMid] ) then
                 iEnd,iState = iMid - 1,0
              else
                 iStart,iState = iMid + 1,1
              end
           end
           table.insert( t,(iMid+iState),value )
           return (iMid+iState)
        end
     end

    local t: table = {}
    table_bininsert(t,  5)
