#ifndef __omniObject_C2Ada__
#define __Ada_OmniObject__
#include "omniObject_C2Ada.hh"
#endif
#include "Ada_OmniRopeAndKey.hh"
#include <omniORB2/CORBA.h>


class omniObject_C2Ada;

class Ada_OmniObject {

public:

  Ada_OmniObject (void);
  // default constructor
  
  Ada_OmniObject (omniObject_C2Ada* cpp_object,
		  int               interface);
  // constructor for proxy objects, only called in C++
  // that makes this Ada_OmniObject point on an already existent
  // omniObject_C2Ada
  
  virtual ~Ada_OmniObject();

  static Ada_OmniObject *Constructor();
  // static constructor.
  // this is a workaround for gnat 3.11p where we cannot
  // write "new Object"
  // it is only called to create local objects
  
  static void Destructor(Ada_OmniObject* o);
  // static destructor that will be called from the Ada code
  // because the virtual destructor cannot be called from tha Ada code

  void initLocalObject (const char* repoID);
  // Initialisation of a local object via call to the
  // omniObject_C2Ada constructor on C_OmniObject
  // For a local object, we have to set the repository_id

  
  void initProxyObject (const char *repoId,
			  Rope *r,
			  _CORBA_Octet *key,
			  size_t keysize,
			  IOP::TaggedProfileList *profiles,
			  _CORBA_Boolean release); 
  // Initialisation of a proxy object via call to the
  // omniObject_C2Ada constructor on CPP_Object
  
  
  static Ada_OmniObject* objectDuplicate(Ada_OmniObject* omniobj);
  // Creation of an Ada_OmniObject referencing the same
  // omniObject ( used for Omniobject.Duplicate )
  
  void objectIsReady();
  // calls omni::objectIsReady on CPP_Object
  // to tell the ORB that this local object is
  // ready to accpet connexions
  
  void disposeObject();
  // calls omni::disposeObject on C_OmniObject
  // it has to be done only for local object
  // to tell the ORB they cannot receive connexions any longer

  bool non_existent();
  // returns true if the ORB is sure that the
  // implementation referenced by this proxy object
  // does not exist
  
  _CORBA_Boolean is_equivalent(Ada_OmniObject * other);
  // return true when CPP objects are equivalent

  _CORBA_ULong hash(_CORBA_ULong maximum);
  // returns a hash value for this object

  void setRopeAndKey(const Ada_OmniRopeAndKey& l,_CORBA_Boolean keepIOP=1);
  // calls the setRopeAndKey function of CPP_Object

  void  getRopeAndKey(Ada_OmniRopeAndKey& l, _CORBA_Boolean &success);
  // calls the getRopeAndKey function of CPP_Object

  void resetRopeAndKey();
  // calls the resetRopeAdnKey function of CPP_Object
  
  void assertObjectExistent();
  // calls the assertObjectExistent function of CPP_Object
  
  _CORBA_Boolean is_proxy();
  // calls the is_proxy function of CPP_Object
  
  virtual void dispatch(Ada_Giop_s &,
			const char *operation,
			_CORBA_Boolean response_expected,
			_CORBA_Boolean& success);
  // default dispatch function for all the hierarchie of
  // Ada Objects. The implementation is made in Ada.
  // (see omniobject.adb)
  // this function is made a procedure because it takes
  // arguments passed by reference

  _CORBA_Boolean Ada_Is_A(const char *repoid);
  // it is implemented in omniobject.ads
  // returns true if this object can be
  // widened/narrow into this interface
  
  const char* getRepositoryID();
  // calls th NP_repositoryId of omniObject
  
  static Ada_OmniObject* string_to_ada_object(const char *repoId);
  // this function executes omni::stringToObject,
  // and cast the result into an Ada_OmniObject.
  // it can only be called by Corba.Orb.String_To_Object

  static Ada_OmniObject* Ada_resolve_initial_references(CORBA::ORB_ptr theORB,
					                const char *identifier);

  
  static Ada_OmniObject* ada_create_objref(const char* repoId,
					   IOP::TaggedProfileList* profiles,
					   _CORBA_Boolean release);
  // this function is called by the Ada code
  // to create aCorba.Object.Ref when unmarshalling
  // out of a bufferedstream.
  // it calls omni:: createObjRef
  // in objectRef.cc L 391

  static char* ada_object_to_string(Ada_OmniObject* objptr);
  // this function calls omni::objectToString
  // on the underlying object
  
  IOP::TaggedProfileList* iopProfiles(); 
  // this function calls omniobject::iopProfiles()
  // on the underlying object


  omniObject_C2Ada *getOmniObject();
  // returns the unserlying CPP_Object
  // used in proxyObjectFactory_C2Ada
  
private:

  void setRepositoryID(const char *repoId);
  // sets the repository id for a local object
  
  void* Implobj;
  // This pointer is only used by the Ada side of this object

  int  Interface;
  // This index is only used by the Ada side of this object

public:
  omniObject_C2Ada *CPP_Object;
  // Pointer on the underlying omniObject_C2Ada object

private:

  bool Init_Ok;
  // This flag tells if an init function was called or not

  void* VTable;
  // This field is only used by Ada. It is needed to interface C++ and Ada  
  
};
