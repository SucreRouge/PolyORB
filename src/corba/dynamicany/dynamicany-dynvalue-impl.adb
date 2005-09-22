------------------------------------------------------------------------------
--                                                                          --
--                           POLYORB COMPONENTS                             --
--                                                                          --
--             D Y N A M I C A N Y . D Y N V A L U E . I M P L              --
--                                                                          --
--                                 B o d y                                  --
--                                                                          --
--            Copyright (C) 2005 Free Software Foundation, Inc.             --
--                                                                          --
-- PolyORB is free software; you  can  redistribute  it and/or modify it    --
-- under terms of the  GNU General Public License as published by the  Free --
-- Software Foundation;  either version 2,  or (at your option)  any  later --
-- version. PolyORB is distributed  in the hope that it will be  useful,    --
-- but WITHOUT ANY WARRANTY;  without even the implied warranty of MERCHAN- --
-- TABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public --
-- License  for more details.  You should have received  a copy of the GNU  --
-- General Public License distributed with PolyORB; see file COPYING. If    --
-- not, write to the Free Software Foundation, 59 Temple Place - Suite 330, --
-- Boston, MA 02111-1307, USA.                                              --
--                                                                          --
-- As a special exception,  if other files  instantiate  generics from this --
-- unit, or you link  this unit with other files  to produce an executable, --
-- this  unit  does not  by itself cause  the resulting  executable  to  be --
-- covered  by the  GNU  General  Public  License.  This exception does not --
-- however invalidate  any other reasons why  the executable file  might be --
-- covered by the  GNU Public License.                                      --
--                                                                          --
--                  PolyORB is maintained by AdaCore                        --
--                     (email: sales@adacore.com)                           --
--                                                                          --
------------------------------------------------------------------------------

with PolyORB.Smart_Pointers;

with DynamicAny.DynAny;
with DynamicAny.DynValueCommon;
with PolyORB.CORBA_P.Dynamic_Any;

package body DynamicAny.DynValue.Impl is

   use PolyORB.Any;
   use PolyORB.Any.TypeCode;

   function Is_Destroyed
     (Self : access DynAny.Impl.Object'Class)
      return Boolean
      renames DynAny.Impl.Internals.Is_Destroyed;

   ----------
   -- Copy --
   ----------

   function Copy (Self : access Object) return DynAny.Local_Ref'Class is
   begin
      if Is_Destroyed (Self) then
         CORBA.Raise_Object_Not_Exist (CORBA.Default_Sys_Member);
      end if;

      return
        PolyORB.CORBA_P.Dynamic_Any.Create
        (CORBA.Internals.To_CORBA_Any
         (DynAny.Impl.Internals.Get_Value (Self)),
         Self.Allow_Truncate,
         null);
   end Copy;

   -------------------------
   -- Current_Member_Kind --
   -------------------------

   function Current_Member_Kind (Self : access Object) return CORBA.TCKind is
   begin
      if Is_Destroyed (Self) then
         CORBA.Raise_Object_Not_Exist (CORBA.Default_Sys_Member);
      end if;

      raise Program_Error;
      return CORBA.Tk_Void;
   end Current_Member_Kind;

   -------------------------
   -- Current_Member_Name --
   -------------------------

   function Current_Member_Name (Self : access Object) return FieldName is
      Result : DynamicAny.FieldName;

   begin
      if Is_Destroyed (Self) then
         CORBA.Raise_Object_Not_Exist (CORBA.Default_Sys_Member);
      end if;

      raise Program_Error;
      return Result;
   end Current_Member_Name;

   -----------------
   -- Get_Members --
   -----------------

   function Get_Members (Self : access Object) return NameValuePairSeq is
      Result : DynamicAny.NameValuePairSeq;

   begin
      if Is_Destroyed (Self) then
         CORBA.Raise_Object_Not_Exist (CORBA.Default_Sys_Member);
      end if;

      raise Program_Error;
      return Result;
   end Get_Members;

   ----------------------------
   -- Get_Members_As_Dyn_Any --
   ----------------------------

   function Get_Members_As_Dyn_Any
     (Self : access Object)
      return NameDynAnyPairSeq
   is
      Result : DynamicAny.NameDynAnyPairSeq;

   begin
      if Is_Destroyed (Self) then
         CORBA.Raise_Object_Not_Exist (CORBA.Default_Sys_Member);
      end if;

      raise Program_Error;
      return Result;
   end Get_Members_As_Dyn_Any;

   ---------------
   -- Internals --
   ---------------

   package body Internals is

      ------------
      -- Create --
      ------------

      function Create
        (Value          : in PolyORB.Any.Any;
         Allow_Truncate : in Boolean;
         Parent         : in DynAny.Impl.Object_Ptr)
         return DynAny.Local_Ref
      is
         Obj    : constant Object_Ptr := new Object;

         Result : DynAny.Local_Ref;

      begin
         pragma Assert (Kind (Get_Type (Value)) = Tk_Value);

         Initialize (Obj, Value, Allow_Truncate, Parent);

         DynAny.Set (Result, PolyORB.Smart_Pointers.Entity_Ptr (Obj));

         return Result;
      end Create;

      function Create
        (Value : in PolyORB.Any.TypeCode.Object)
         return DynAny.Local_Ref
      is
         Obj    : constant Object_Ptr := new Object;

         Result : DynAny.Local_Ref;

      begin
         pragma Assert (Kind (Value) = Tk_Array);

         Initialize (Obj, Value);

         DynAny.Set (Result, PolyORB.Smart_Pointers.Entity_Ptr (Obj));

         return Result;
      end Create;

      ----------------
      -- Initialize --
      ----------------

      procedure Initialize
        (Self     : access Object'Class;
         IDL_Type : in     PolyORB.Any.TypeCode.Object)
      is
      begin
         DynValueCommon.Impl.Internals.Initialize (Self, IDL_Type);

         Self.Allow_Truncate := True;
      end Initialize;

      procedure Initialize
        (Self           : access Object'Class;
         Value          : in     PolyORB.Any.Any;
         Allow_Truncate : in     Boolean;
         Parent         : in     DynAny.Impl.Object_Ptr)
      is
      begin
         DynValueCommon.Impl.Internals.Initialize (Self, Value, Parent);

         Self.Allow_Truncate := Allow_Truncate;
      end Initialize;

   end Internals;

   ----------
   -- Is_A --
   ----------

   function Is_A
     (Self            : access Object;
      Logical_Type_Id : in     Standard.String)
      return Boolean
   is
      pragma Unreferenced (Self);

   begin
      return CORBA.Is_Equivalent
        (Logical_Type_Id,
         DynamicAny.DynValue.Repository_Id)
        or else CORBA.Is_Equivalent
        (Logical_Type_Id,
         "IDL:omg.org/CORBA/Object:1.0")
        or else CORBA.Is_Equivalent
        (Logical_Type_Id,
         DynamicAny.DynValueCommon.Repository_Id)
        or else CORBA.Is_Equivalent
        (Logical_Type_Id,
         DynamicAny.DynAny.Repository_Id);
   end Is_A;

   -----------------
   -- Set_Members --
   -----------------

   procedure Set_Members
     (Self  : access Object;
      Value : in     NameValuePairSeq)
   is
      pragma Unreferenced (Value);

   begin
      if Is_Destroyed (Self) then
         CORBA.Raise_Object_Not_Exist (CORBA.Default_Sys_Member);
      end if;

      raise Program_Error;
   end Set_Members;

   ----------------------------
   -- Set_Members_As_Dyn_Any --
   ----------------------------

   procedure Set_Members_As_Dyn_Any
     (Self  : access Object;
      Value : in     NameDynAnyPairSeq)
   is
      pragma Unreferenced (Value);

   begin
      if Is_Destroyed (Self) then
         CORBA.Raise_Object_Not_Exist (CORBA.Default_Sys_Member);
      end if;

      raise Program_Error;
   end Set_Members_As_Dyn_Any;

end DynamicAny.DynValue.Impl;