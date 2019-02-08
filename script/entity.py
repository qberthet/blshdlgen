class Entity:

    def get_name(self):
        return self.id.split("/")[-1]

    def factory(entity_id, dp):
        entity_name = entity_id.split("/")[-1]
        entity_filename   = cwd + "/entities/" + entity_id + "/" + entity_name + ".vhd"
        entity_class_file = cwd + "/entities/" + entity_id + "/" + entity_name + ".py"
        if not os.path.isfile(entity_filename):
            #raise AssertionError("Entity file not found:" + entity_filename)
            print "Entity file not found:" + entity_filename
            return None
        if not os.path.isfile(entity_class_file):
            #raise AssertionError("Entity class file not found:" + entity_class_file)
            print "Entity class file not found:" + entity_class_file
            return None
        base_name = os.path.basename(entity_filename)
        entity_name = os.path.splitext(base_name)[0]
        # Create object 'obj'
        load(entity_class_file)

        if (entity_id != obj.id):
            #raise AssertionError("incorrect object created: " + str(obj.__class__.__name__))
            print "Invalid entity file:", entity_name
            return None
        return obj

    factory = staticmethod(factory)

    def get_src(self):
        src_list = []
        if hasattr(self, 'src'):
            for file_name in self.src:
                file_path = self.id + "/" + file_name
                src_list += [ file_path ]
        else:
            # FIXME default to {entity_id}.vhd as before?
            print "Error, entity does not list sources files"
        return src_list

    def get_src_with_dep(self, dp):
        src_list = []
        # recursively check for dependancies
        if hasattr(self, 'dep'):
            for dep_id in self.dep:
                temp_entity = Entity.factory(dep_id, dp)
                if temp_entity:
                    # Get dependency source list
                    dep_src_list = temp_entity.get_src_with_dep(dp)
                    # Remove file already in src_list
                    dep_src_list = [x for x in dep_src_list if x not in src_list]
                    # Add remaining sources to source list
                    src_list += dep_src_list
                    del temp_entity
                else:
                    print "Error, failed to create object for dependency:" + dep_id
        # Add sources files for this entity
        src_list += self.get_src()
        return src_list

    def lst():
        pattern = '*.py'
        path = cwd + "/entities/"
        result = []
        for root, dirs, files in os.walk(path):
            for name in files:
                if fnmatch.fnmatch(name, pattern):
                    temp = os.path.normpath(root)
                    entity_id =  os.path.relpath(temp, cwd + "/entities/")
                    result.append(entity_id)
        return sorted(result)

    lst = staticmethod(lst)

    def print_lst():
        for dp_id in Entity.lst():
            print dp_id

    print_lst = staticmethod(print_lst)