#encoding: utf-8
require 'rubygems'
require 'osx/cocoa'
require 'json'
require 'net/http'
require 'active_support'

OSX.require_framework 'CoreData'

class CoreDataStore
  def create_entity name, props={}, relationships={}
    entity = OSX::NSEntityDescription.insertNewObjectForEntityForName_inManagedObjectContext(name, context)
    props.each do |k,v|
      entity.setValue_forKey v, k
    end
    relationships.each do |k, objects|
      collection = entity.mutableSetValueForKey(k)
      objects.each {|o| collection.addObject o}
    end
    entity
  end

  def initialize(data_store_path, mom_path)
    @data_store_path = data_store_path
    @mom_path = mom_path
  end

  def context
    @context ||= OSX::NSManagedObjectContext.alloc.init.tap do |context|
      model = OSX::NSManagedObjectModel.alloc.initWithContentsOfURL(OSX::NSURL.fileURLWithPath(@mom_path))
      coordinator = OSX::NSPersistentStoreCoordinator.alloc.initWithManagedObjectModel(model)

      result, error = coordinator.addPersistentStoreWithType_configuration_URL_options_error(
         OSX::NSSQLiteStoreType, nil, OSX::NSURL.fileURLWithPath(@data_store_path), nil)
      if !result
        raise "Add persistent store failed: #{error.description}"
      end
      context.setPersistentStoreCoordinator coordinator
    end
  end

  def save
    res, error = context.save_
    if !res
      raise "Save failed: #{error.description}"
    end
    res
  end
end


store = CoreDataStore.new('../ios/resources/Golftracker.sqlite', '../ios/resources/Golftracker.momd/0.0.1.mom')


res = Net::HTTP.get(URI.parse('http://lvh.me:3000/courses.json'))
JSON.parse(res).each do |c|
  holes = []
  c["holes"].each do |hole|
    holes << store.create_entity("Hole", {'id' => hole["id"], 'course_id' => hole["course_id"],  'hcp' => hole["hcp"], 'nr' => hole["nr"], 'par' => hole["par"], 'length' => hole["length"]})
  end
  updated = OSX::NSDate.dateWithNaturalLanguageString(c["updated_at"])
  course = store.create_entity('Course', {'id' => c["id"], 'name' => c["name"], 'par' => c["par"], 'holes_count' => c["holes_count"], 'updated_at' => updated }, {'holes' => holes})
  puts "Saved course #{c["name"]} with #{holes.length} holes"
end
store.save
