------------------------------------------------------------------------------
--                                                                          --
--                           POLYORB COMPONENTS                             --
--                                                                          --
--           P O L Y O R B . T R A N S P O R T . D A T A G R A M            --
--                                                                          --
--                                 B o d y                                  --
--                                                                          --
--         Copyright (C) 2003-2017, Free Software Foundation, Inc.          --
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

with PolyORB.Binding_Objects;
with PolyORB.Log;
with PolyORB.Filters;
with PolyORB.Filters.Iface;
with PolyORB.ORB.Iface;

package body PolyORB.Transport.Datagram is

   use PolyORB.Log;

   package L is new PolyORB.Log.Facility_Log ("polyorb.transport.datagram");
   procedure O (Message : String; Level : Log_Level := Debug)
     renames L.Output;
   function C (Level : Log_Level := Debug) return Boolean
     renames L.Enabled;

   ---------------------
   -- Create_Endpoint --
   ---------------------

   function Create_Endpoint
     (TAP : access Datagram_Transport_Access_Point)
     return Datagram_Transport_Endpoint_Access
   is
      pragma Warnings (Off);
      pragma Unreferenced (TAP);
      pragma Warnings (On);

   begin
      pragma Debug (C, O ("Return null endpoint"));
      return null;
   end Create_Endpoint;

   ------------------
   -- Handle_Event --
   ------------------

   overriding procedure Handle_Event
     (H : access Datagram_TAP_AES_Event_Handler)
   is
      use PolyORB.ORB;

      --  Create associated Endpoint

      New_TE : constant Transport_Endpoint_Access
        := Transport_Endpoint_Access
        (Create_Endpoint (Datagram_Transport_Access_Point_Access (H.TAP)));

   begin
      if New_TE /= null then
         pragma Debug (C, O ("Create and register endpoint"));

         Binding_Objects.Setup_Binding_Object
           (ORB     => Components.Component_Access (H.ORB),
            TE      => New_TE,
            FFC     => H.Filter_Factory_Chain.all,
            BO_Ref  => New_TE.Dependent_Binding_Object,
            Pro     => null);
         --  XXX Until bidirectional BOs are implemented,
         --  We mark Server BOs as having a null Profile
         --  cf. PolyORB.ORB.Find_Reusable_Binding_Object.

         ORB.Register_Binding_Object
           (H.ORB,
            New_TE.Dependent_Binding_Object,
            ORB.Server);

         --  Setup binding object
      end if;
   end Handle_Event;

   --------------------
   -- Handle_Message --
   --------------------

   overriding function Handle_Message
     (TE  : not null access Datagram_Transport_Endpoint;
      Msg : Components.Message'Class) return Components.Message'Class
   is
      use PolyORB.Buffers;
      use PolyORB.Components;
      use PolyORB.Errors;
      use PolyORB.Filters;
      use PolyORB.Filters.Iface;

      Nothing : Components.Null_Message;
   begin
      if Msg in Data_Expected'Class then
         declare
            DE : Data_Expected renames Data_Expected (Msg);
         begin
            pragma Assert (DE.In_Buf /= null);
            TE.In_Buf := DE.In_Buf;
            TE.Max    := DE.Max;
         end;

         return Emit
           (TE.Server, ORB.Iface.Monitor_Endpoint'
              (TE => Transport_Endpoint_Access (TE)));

      elsif Msg in Data_Indication then
         pragma Debug (C, O ("Data received"));

         declare
            use type Ada.Streams.Stream_Element_Count;
            Size : Ada.Streams.Stream_Element_Count := TE.Max;
            Error : Errors.Error_Container;
         begin
            if TE.In_Buf /= null then
               Read
                 (Transport_Endpoint'Class (TE.all), TE.In_Buf, Size, Error);
            end if;

            if TE.In_Buf = null
              or else (Size = 0 and then not Is_Error (Error))
            then
               Throw (Error, Comm_Failure_E,
                      System_Exception_Members'
                      (Minor => 0, Completed => Completed_Maybe));
            end if;

            if not Is_Error (Error) then
               return Emit (TE.Upper, Data_Indication'(Data_Amount => Size));

            else
               return Filter_Error'(Error => Error);

            end if;
         end;

      elsif Msg in Data_Out then
         declare
            Error : Errors.Error_Container;
         begin
            Write
              (Transport_Endpoint'Class (TE.all),
               Data_Out (Msg).Out_Buf, Error);

            if Errors.Is_Error (Error) then
               return Filter_Error'(Error => Error);
            end if;
         end;

      elsif Msg in Set_Server then
         TE.Server := Set_Server (Msg).Server;
         TE.Binding_Object :=
           Smart_Pointers.Entity_Ptr (Set_Server (Msg).Binding_Object);
         return Emit (TE.Upper, Msg);

      elsif Msg in Disconnect_Indication then
         Close (Transport_Endpoint'Class (TE.all)'Access);
         return Emit (TE.Upper, Msg);

      elsif Msg in Disconnect_Request then
         Close (Transport_Endpoint'Class (TE.all)'Access);

      else
         return Transport.Handle_Message
                 (Transport_Endpoint (TE.all)'Access, Msg);
      end if;

      return Nothing;
   end Handle_Message;

end PolyORB.Transport.Datagram;
