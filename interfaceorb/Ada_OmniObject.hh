////////////////////////////////////////////////////////////////////////////
////                                                                    ////
////     This class is is both a C class and an Ada Class (see          ////
////     omniObject.ads). It is wrapped around omniObject_C2Ada         ////
////     in order to avoid the presence of non default construc-        ////
////     tors.                                                          ////
////     So, it provides the same functions as omniObject_C2Ada         ////
////     except that constructors are replaced by Init functions.       ////
////     It has also a pointer on the underlining omniObject_C2Ada      ////
////     object                                                         ////
////                                                                    ////
////                                                                    ////
////                Date : 02/16/99                                     ////
////                                                                    ////
////                authors : Sebastien Ponce                           ////
////                                                                    ////
////////////////////////////////////////////////////////////////////////////


#ifndef __omniObject_C2Ada__
#define __Ada_OmniObject__
#include "omniObject_C2Ada.hh"
#endif

class omniObject_C2Ada ;

class Ada_OmniObject {

public:

  Ada_OmniObject (void) ;
  // default constructor
  
  virtual ~Ada_OmniObject() ;

  static void Destructor(Ada_OmniObject* o) ;
  // static destructor that will be called from the Ada code
  // because the virtual destructor cannot be called from tha Ada code


  void Init ();
  // Initialisation of a local object via call to the
  // omniObject_C2Ada constructor on C_OmniObject
  
  void Init (const char *repoId,
	     Rope *r,
	     _CORBA_Octet *key,
	     size_t keysize,
	     IOP::TaggedProfileList *profiles,
	     _CORBA_Boolean release); 
  // Initialisation of a proxy object via call to the
  // omniObject_C2Ada constructor on C_OmniObject

  void Init (omniObject_C2Ada *omniobj);
  //Initialisation by giving the underlying omniObject_C2Ada pointer
  
  void setRopeAndKey(const omniRopeAndKey& l,_CORBA_Boolean keepIOP=1);
  // calls the setRopeAndKey function of C_OmniObject
  
  _CORBA_Boolean getRopeAndKey(omniRopeAndKey& l);
  // calls the getRopeAndKey function of C_OmniObject
  
  void assertObjectExistent();
  // calls the assertObjectExistent function of C_OmniObject
  
  _CORBA_Boolean is_proxy();
  // calls the is_proxy function of C_OmniObject

  virtual _CORBA_Boolean dispatch(GIOP_S &,
				  const char *operation,
				  _CORBA_Boolean response_expected);
  // default dispatch function for all the hierarchie of
  // Ada Objects. The implementation is made in Ada.
  // (see omniobject.adb)

  void setRepositoryID(const char* repoId) ;
  // call the PR_IRRepositoryId of omniObject
  
  const char* getRepositoryID() ;
  // calls th NP_repositoryId of omniObject
  
  omniObject_C2Ada *getOmniObject() ;
  // returns the underlying omniObject_C2Ada
  
private:
  void* ada_pointer ;
  // This pointer is only used by the Ada side of this object
  
  omniObject_C2Ada *C_OmniObject;
  // Pointer on the underlying omniObject_C2Ada object
  
  bool Init_Ok;
  // This flag tells if an init function was called or not

};

extern void raise_ada_exception (const char *msg) ;
  // this function allows C code to raise Ada exception
  // It is implemented in Ada and only raise a No_Initialisation
  // exception with the message msg. (see corba.ads)

