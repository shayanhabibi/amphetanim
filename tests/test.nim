## Want to see if variants only present the fields that are actually
## present or if they just keep hold of all of them

import pkg/loony

type SomeRefObject = ref object

var loo = initLoonyQueue[SomeRefObject]()

var sro = new SomeRefObject

loo.push sro


# template getMeType(o: typed): ptr TNimType =
#   cast[PNimType](getTypeInfo(o))



# var t = getMeType i
# proc woahImpl(x: ptr TNimType)

# proc echoChildNodesImpl(x: TNimNode)

# proc echoChildNodes(x: TNimNode) =
#   # Lets print the name of the node
#   echo x.name
#   # Check if its got sons
#   if not x.sons.isNil:
#     for son in x.sons[]:
#       if son.isNil:
#         break
#       # Any sons that it has we want to do the same
#       echoChildNodesImpl(son[])
#       if not son.typ.isNil:
#         # If it has a type then we'll chuck that in to get checked for nodes
#         woahImpl(son.typ)

# proc echoChildNodesImpl(x: TNimNode) =
#   echoChildNodes x

# proc woah(t: ptr TNimType) =
#   block:
#     # We'll check the ptr to the type to see if its nil
#     if t.isNil:
#       break
#     # If not we'll check to see if it has a node; break else
#     if t[].node.isNil:
#       break
#     # Now lets iterate over that node 
#     echoChildNodes t[].node[]
#     # Also check if theres a base type
#     if not t[].base.isNil:
#       # If there is lets check its nodes ;_;
#       woahImpl(t[].base)



# proc woahImpl(x: ptr TNimType) =
#   woah(x)

# woah t