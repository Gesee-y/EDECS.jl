#########################################################################################################################
###################################################### OPERATIONS #######################################################
#########################################################################################################################

######################################################## Export #########################################################

export create_entity!, request_entity!, remove_entity!

######################################################### Core ##########################################################

"""
    create_entity!(ecs::ECSManager, comp::NamedTuple; parent=ecs, size=DEFAULT_PARTITION_SIZE)

This will create a new entity in the manager `ecs`, with the components `comp` and with the given `parent`.
If this entity is the first one with this set of argument, a new partition with the given `size` will be created

    create_entity!(ecs::ECSManager, key::Tuple; parent=ecs, size=DEFAULT_PARTITION_SIZE)

This will create entity with the given signature but with uninitialized components.
`key` is a tuple of symbols, where each symbol is a component.
"""
function create_entity!(ecs::ECSManager, comp::NamedTuple; parent=ecs, size=DEFAULT_PARTITION_SIZE)
	table = ecs.table
	key = keys(comp)
	partitions = table.partitions

    # We get the bit representation of that set of components
	signature = get_bits(table, key)
	!haskey(partitions, signature) && createpartition(table, signature, size)
	id = addtopartition(table, signature) # We add the entity to the correct partition

	entity = Entity(id, signature, key, WeakRef(ecs))
	setrow!(table, id, comp) # We then initialize the components

	table.entities[id] = entity

	return entity
end
function create_entity!(ecs::ECSManager, key::Tuple; parent=ecs, size=DEFAULT_PARTITION_SIZE)
	table = ecs.table
	key = to_symbol.(key)
	partitions = table.partitions

    # We get the bit representation of that set of components
	signature = get_bits(table, key)
	!haskey(partitions, signature) && createpartition(table, signature, size)
	id = addtopartition(table, signature) # We add the entity to the correct partition

	entity = Entity(id, signature, key, WeakRef(ecs))
	table.entities[id] = entity

	return entity
end
create_entity!(ecs::ECSManager; kwargs...) = create_entity!(ecs, NamedTuple(kwargs))

"""
    request_entity!(ecs::ECSManager, comp::NamedTuple, count::Int; parent=ecs)

This function create `count` number of entity with the given components in `comp` and return an `EntityRange`.
Note that this function doesn't hysically make the entities. They are there and can be processed.
But you will have to use `get_entity` on that range.

    request_entity!(ecs::ECSManager, key::Tuple, count::Int; parent=ecs)

Do the same as above but doesn't initialize the components so they just have garbage value.
Note that this is significantly faster than the other version of this function.
"""
function request_entity!(ecs::ECSManager, comp::NamedTuple, count::Int; parent=ecs)
	table = ecs.table
	key = keys(comp)
	partitions = table.partitions
    s = table.entity_count+1
    e = table.entity_count+count
    parent_id = get_id(parent)
    ref = WeakRef(ecs)
    entities = Vector{Entity}(undef, count)

    # We get the bit representation of that set of components
	signature = get_bits(table, key)
	allocate_entity(table, count, signature)
    
    for i in s:e
    	setrow!(table, i, comp)
    end

    r = EntityRange(s,e,0,ref,key,signature)
	return r
end
function request_entity!(ecs::ECSManager, key::Tuple, count::Int; parent=ecs)
	table = ecs.table
	partitions = table.partitions
    s = table.entity_count+1
    e = table.entity_count+count
    parent_id = get_id(parent)
    ref = WeakRef(ecs)

    # We get the bit representation of that set of components
	signature = get_bits(table, key)
	allocate_entity(table, count, signature)
    
    r = EntityRange(s,e,0,ref,key,parent_id,signature)
	return r
end

"""
    remove_entity!(ecs::ECSManager, e::Entity)

This remove an entity from the world.
"""
function remove_entity!(ecs::ECSManager, e::Entity)
	table = ecs.table
	swap_remove!(table, e)
	e.world = WeakRef()
end

"""

"""
function attach_component(ecs::ECSManager, e::Entity, c::AbstractComponent)
	table = ecs.table
	symb = to_symbol(c)
	if !(symb in e.components)
		symb = to_symbol(c)
		comp = (e.components..., symb)
		signature = e.archetype | get_bits(table, symb)
		change_archetype(table, e, signature)
		setrow!(table, get_id(e), c)
		e.components = comp
		e.signature = signature
	end
end

function detach_component(ecs::ECSManager, e::Entity, T::Type)
	table = ecs.table
	symb = to_symbol(c)
	if symb in e.components
		comp = filter(c -> c != symb, e.components)
		signature = e.archetype & get_bits(table, symb)
		e.components = comp
		change_archetype(table, e, signature)
		e.signature = signature
	end
end