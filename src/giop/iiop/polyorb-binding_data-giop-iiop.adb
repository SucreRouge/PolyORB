------------------------------------------------------------------------------
--                                                                          --
--                           POLYORB COMPONENTS                             --
--                                                                          --
--       P O L Y O R B . B I N D I N G _ D A T A . G I O P . I I O P        --
--                                                                          --
--                                 B o d y                                  --
--                                                                          --
--         Copyright (C) 2002-2017, Free Software Foundation, Inc.          --
--                                                                          --
-- This is free software;  you can redistribute it  and/or modify it  under --
-- terms of the  GNU General Public License as published  by the Free Soft- --
-- ware  Foundation;  either version 3,  or (at your option) any later ver- --
-- sion.  This software is distributed in the hope  that it will be useful, --
-- but WITHOUT ANY WARRANTY;  without even the implied warranty of MERCHAN- --
-- TABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public --
-- License for  more details.                                               --
--                                                                          --
-- As a special exception under Section 7 of GPL version 3, you are granted --
-- additional permissions described in the GCC Runtime Library Exception,   --
-- version 3.1, as published by the Free Software Foundation.               --
--                                                                          --
-- You should have received a copy of the GNU General Public License and    --
-- a copy of the GCC Runtime Library Exception along with this program;     --
-- see the files COPYING3 and COPYING.RUNTIME respectively.  If not, see    --
-- <http://www.gnu.org/licenses/>.                                          --
--                                                                          --
--                  PolyORB is maintained by AdaCore                        --
--                     (email: sales@adacore.com)                           --
--                                                                          --
------------------------------------------------------------------------------

pragma Ada_2012;

--  Binding data concrete implementation for IIOP.

with Ada.Streams;

with PolyORB.Binding_Data.GIOP.INET;
with PolyORB.Binding_Data_QoS;
with PolyORB.GIOP_P.Transport_Mechanisms.IIOP;
with PolyORB.Initialization;
with PolyORB.Log;
with PolyORB.Obj_Adapters;
with PolyORB.ORB;
with PolyORB.Parameters;
with PolyORB.QoS.Tagged_Components;
with PolyORB.References.Corbaloc;
with PolyORB.References.IOR;
with PolyORB.Setup;
with PolyORB.Utils.Sockets;
with PolyORB.Utils.Strings;

package body PolyORB.Binding_Data.GIOP.IIOP is

   use PolyORB.Binding_Data.GIOP.INET;
   use PolyORB.GIOP_P.Tagged_Components;
   use PolyORB.GIOP_P.Transport_Mechanisms;
   use PolyORB.GIOP_P.Transport_Mechanisms.IIOP;
   use PolyORB.Log;
   use PolyORB.Objects;
   use PolyORB.References.Corbaloc;
   use PolyORB.References.IOR;

   package L is new PolyORB.Log.Facility_Log
     ("polyorb.binding_data.giop.iiop");
   procedure O (Message : Standard.String; Level : Log_Level := Debug)
     renames L.Output;
   function C (Level : Log_Level := Debug) return Boolean
     renames L.Enabled;

   IIOP_Corbaloc_Prefix : constant String := "iiop";

   Preference : Profile_Preference;
   --  Global variable: the preference to be returned
   --  by Get_Profile_Preference for IIOP profiles.

   function Profile_To_Corbaloc (P : Profile_Access) return String;
   function Corbaloc_To_Profile (Str : String) return Profile_Access;

   function Get_Primary_IIOP_Address
     (Profile : IIOP_Profile_Type) return Utils.Sockets.Socket_Name;
   --  Return primary address of profile (address of the first profile's
   --  transport mechanims)

   procedure Add_Additional_Transport_Mechanisms
     (P : access IIOP_Profile_Type);
   --  Add transport mechanisms associated with tagged components in P.
   --  The primary transport mechanism (associated with the base IIOP profile
   --  body) should already have been created.

   procedure Add_Profile_QoS (P : access IIOP_Profile_Type);
   --  Add profile QoS parameters. This subprogram should be called
   --  after calculation of additional transport mechanisms.

   -------------------------------------
   -- Add_Transport_Mechanism_Factory --
   -------------------------------------

   procedure Add_Transport_Mechanism_Factory
     (PF : in out IIOP_Profile_Factory;
      MF :        Transport_Mechanism_Factory_Access)
   is
   begin
      Append (PF.Mechanisms, MF);
   end Add_Transport_Mechanism_Factory;

   -----------------------------------------
   -- Add_Additional_Transport_Mechanisms --
   -----------------------------------------

   procedure Add_Additional_Transport_Mechanisms
     (P : access IIOP_Profile_Type)
   is
   begin
      Create_Transport_Mechanisms
        (P.Components, Profile_Access (P), P.Mechanisms);
   end Add_Additional_Transport_Mechanisms;

   ---------------------
   -- Add_Profile_QoS --
   ---------------------

   procedure Add_Profile_QoS (P : access IIOP_Profile_Type) is
      use PolyORB.QoS;
      use PolyORB.QoS.Tagged_Components;

   begin
      PolyORB.Binding_Data_QoS.Set_Profile_QoS
        (P,
         GIOP_Tagged_Components,
         new QoS_GIOP_Tagged_Components_Parameter'
         (GIOP_Tagged_Components,
          Create_QoS_GIOP_Tagged_Components_List (P.Components)));

      if Security_Fetch_QoS /= null then
         Security_Fetch_QoS (P);
      end if;
   end Add_Profile_QoS;

   ---------------------
   -- Get_Profile_Tag --
   ---------------------

   overriding function Get_Profile_Tag
     (Profile : IIOP_Profile_Type)
     return Profile_Tag
   is
      pragma Unreferenced (Profile);

   begin
      return Tag_Internet_IOP;
   end Get_Profile_Tag;

   ----------------------------
   -- Get_Profile_Preference --
   ----------------------------

   overriding function Get_Profile_Preference
     (Profile : IIOP_Profile_Type)
     return Profile_Preference
   is
      pragma Unreferenced (Profile);

   begin
      return Preference;
   end Get_Profile_Preference;

   ------------------------------
   -- Get_Primary_IIOP_Address --
   ------------------------------

   function Get_Primary_IIOP_Address
     (Profile : IIOP_Profile_Type) return Utils.Sockets.Socket_Name
   is
   begin
      return
         Primary_Address_Of
         (IIOP_Transport_Mechanism
          (Get_Primary_Transport_Mechanism (Profile).all));
   end Get_Primary_IIOP_Address;

   --------------------
   -- Create_Factory --
   --------------------

   overriding function Create_Factory
     (TAP : not null access Transport.Transport_Access_Point'Class)
      return IIOP_Profile_Factory
   is
      MF : constant Transport_Mechanism_Factory_Access :=
        new IIOP_Transport_Mechanism_Factory;

   begin
      return PF : IIOP_Profile_Factory do
         Create_Factory (MF.all, TAP);
         Append (PF.Mechanisms, MF);
      end return;
   end Create_Factory;

   --------------------
   -- Create_Profile --
   --------------------

   overriding function Create_Profile
     (PF  : access IIOP_Profile_Factory;
      Oid :        Objects.Object_Id)
     return Profile_Access
   is
      use Transport_Mechanism_Factory_Lists;

      Result  : constant Profile_Access := new IIOP_Profile_Type;
      TResult : IIOP_Profile_Type renames IIOP_Profile_Type (Result.all);

      Iter    : Transport_Mechanism_Factory_Lists.Iterator
        := First (PF.Mechanisms);

   begin
      TResult.Version_Major := IIOP_Version_Major;
      TResult.Version_Minor := IIOP_Version_Minor;
      TResult.Object_Id     := new Object_Id'(Oid);

      --  Create primary transport mechanism (which has no associated tagged
      --  component).

      Append
        (TResult.Mechanisms,
         Create_Transport_Mechanism
         (IIOP_Transport_Mechanism_Factory (Value (Iter).all.all)));

      --  Fetch tagged components for Oid

      TResult.Components := Fetch_Components (TResult.Object_Id);

      --  Create tagged components for additional transport mechanisms

      while not Last (Iter) loop
         Add
           (TResult.Components,
            Create_Tagged_Components (Value (Iter).all.all));

         Next (Iter);
      end loop;

      --  Create tagged components attached to the Object Adapter

      declare
         use Ada.Streams;
         use PolyORB.Errors;
         use PolyORB.QoS;
         use PolyORB.QoS.Tagged_Components;

         Error  : Error_Container;
         QoS    : QoS_Parameters;

      begin
         PolyORB.Obj_Adapters.Get_QoS
           (PolyORB.ORB.Object_Adapter (PolyORB.Setup.The_ORB),
            Oid,
            QoS,
            Error);

         if QoS (GIOP_Tagged_Components) /= null then
            declare
               use GIOP_Tagged_Component_Lists;

               Iter : GIOP_Tagged_Component_Lists.Iterator
                 := First (QoS_GIOP_Tagged_Components_Parameter
                           (QoS (GIOP_Tagged_Components).all).Components);

            begin
               while not Last (Iter) loop
                  Add
                    (TResult.Components,
                     Create_Unknown_Component
                     (Tag_Value (Value (Iter).Tag),
                      new Stream_Element_Array'(Value (Iter).Data.all)));
                  Next (Iter);
               end loop;
            end;
         end if;

         --  Create security related tagged component

         if Security_Fetch_Tagged_Component /= null then
            declare
               Sec_TC : constant Tagged_Component_Access :=
                 Security_Fetch_Tagged_Component (Oid);

            begin
               if Sec_TC /= null then
                  Add (TResult.Components, Sec_TC);
               end if;
            end;
         end if;
      end;

      --  Now create additional transport mechanisms from tagged components

      Add_Additional_Transport_Mechanisms (TResult'Access);

      Add_Profile_QoS (TResult'Access);

      return Result;
   end Create_Profile;

   -------------------------------------
   -- Disable_Unprotected_Invocations --
   -------------------------------------

   procedure Disable_Unprotected_Invocations
     (PF : in out IIOP_Profile_Factory)
   is
   begin
      Disable_Transport_Mechanism
        (IIOP_Transport_Mechanism_Factory
         (Element (PF.Mechanisms, 0).all.all));
   end Disable_Unprotected_Invocations;

   -----------------------
   -- Duplicate_Profile --
   -----------------------

   overriding function Duplicate_Profile
     (P : IIOP_Profile_Type)
     return Profile_Access
   is
      Result : constant Profile_Access := new IIOP_Profile_Type;

      TResult : IIOP_Profile_Type renames IIOP_Profile_Type (Result.all);

   begin
      TResult.Version_Major := P.Version_Major;
      TResult.Version_Minor := P.Version_Minor;
      TResult.Object_Id     := new Object_Id'(P.Object_Id.all);
      TResult.Components    := Deep_Copy (P.Components);

      --  Duplicate Primary Transport Mechanism

      Append
        (TResult.Mechanisms,
         new IIOP_Transport_Mechanism'
         (Duplicate (IIOP_Transport_Mechanism
                     (Element (P.Mechanisms, 0).all.all))));

      Add_Additional_Transport_Mechanisms (TResult'Access);
      Add_Profile_QoS (TResult'Access);

      return Result;
   end Duplicate_Profile;

   --------------------------------
   -- Marshall_IIOP_Profile_Body --
   --------------------------------

   procedure Marshall_IIOP_Profile_Body
     (Buf     : access Buffer_Type;
      Profile :        Profile_Access)
   is
   begin
      Common_Marshall_Profile_Body
        (Buf,
         Profile,
         Get_Primary_IIOP_Address (IIOP_Profile_Type (Profile.all)),
         True);
   end Marshall_IIOP_Profile_Body;

   ----------------------------------
   -- Unmarshall_IIOP_Profile_Body --
   ----------------------------------

   function Unmarshall_IIOP_Profile_Body
     (Buffer : access Buffer_Type)
      return Profile_Access
   is
      Result  : constant Profile_Access := new IIOP_Profile_Type;
      TResult : IIOP_Profile_Type renames IIOP_Profile_Type (Result.all);
      Address : constant Utils.Sockets.Socket_Name :=
        Common_Unmarshall_Profile_Body
          (Buffer,
           Result,
           Unmarshall_Object_Id         => True,
           Unmarshall_Tagged_Components => False);
   begin
      --  Create primary transport mechanism

      Append (TResult.Mechanisms, Create_Transport_Mechanism (Address));

      Add_Additional_Transport_Mechanisms (TResult'Access);
      Add_Profile_QoS (TResult'Access);

      return Result;
   end Unmarshall_IIOP_Profile_Body;

   -----------
   -- Image --
   -----------

   overriding function Image (Prof : IIOP_Profile_Type) return String is
   begin
      return "Address : "
        & PolyORB.Utils.Sockets.Image (Get_Primary_IIOP_Address (Prof))
        & ", Object_Id : "
        & PolyORB.Objects.Image (Prof.Object_Id.all);
   end Image;

   -------------------------
   -- Profile_To_Corbaloc --
   -------------------------

   function Profile_To_Corbaloc (P : Profile_Access) return String is
   begin
      pragma Debug (C, O ("IIOP Profile to corbaloc"));
      return Common_IIOP_DIOP_Profile_To_Corbaloc
        (P,
         Get_Primary_IIOP_Address (IIOP_Profile_Type (P.all)),
         IIOP_Corbaloc_Prefix);
   end Profile_To_Corbaloc;

   -------------------------
   -- Corbaloc_To_Profile --
   -------------------------

   function Corbaloc_To_Profile (Str : String) return Profile_Access is
      use Utils.Sockets;
      Result  : aliased Profile_Access := new IIOP_Profile_Type;
      Address : constant Socket_Name :=
        Common_IIOP_DIOP_Corbaloc_To_Profile (Str,
          IIOP_Version_Major, IIOP_Version_Minor, Result'Access);
   begin
      if Result /= null then
         --  Create primary transport mechanism

         Append
           (IIOP_Profile_Type (Result.all).Mechanisms,
            Create_Transport_Mechanism (Address));
      end if;

      return Result;
   end Corbaloc_To_Profile;

   ----------------
   -- Initialize --
   ----------------

   procedure Initialize;

   procedure Initialize is
      Preference_Offset : constant String
        := PolyORB.Parameters.Get_Conf
        (Section => "iiop",
         Key     => "polyorb.binding_data.iiop.preference",
         Default => "0");

   begin
      Preference := Preference_Default + Profile_Preference'Value
        (Preference_Offset);
      Register
       (Tag_Internet_IOP,
        Marshall_IIOP_Profile_Body'Access,
        Unmarshall_IIOP_Profile_Body'Access);
      Register
        (Tag_Internet_IOP,
         IIOP_Corbaloc_Prefix,
         Profile_To_Corbaloc'Access,
         Corbaloc_To_Profile'Access);
   end Initialize;

   use PolyORB.Initialization;
   use PolyORB.Initialization.String_Lists;
   use PolyORB.Utils.Strings;

begin
   Register_Module
     (Module_Info'
      (Name      => +"binding_data.iiop",
       Conflicts => Empty,
       Depends   => +"protocols.giop.iiop" & "sockets",
       Provides  => +"binding_factories",
       Implicit  => False,
       Init      => Initialize'Access,
       Shutdown  => null));
end PolyORB.Binding_Data.GIOP.IIOP;
