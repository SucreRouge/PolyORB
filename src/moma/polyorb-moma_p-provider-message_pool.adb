------------------------------------------------------------------------------
--                                                                          --
--                           POLYORB COMPONENTS                             --
--                                                                          --
--                  POLYORB.MOMA_P.PROVIDER.MESSAGE_POOL                    --
--                                                                          --
--                                 B o d y                                  --
--                                                                          --
--         Copyright (C) 2002-2004 Free Software Foundation, Inc.           --
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
--                PolyORB is maintained by ACT Europe.                      --
--                    (email: sales@act-europe.fr)                          --
--                                                                          --
------------------------------------------------------------------------------

--  Message_Pool servant.

with MOMA.Destinations;
with MOMA.Messages;
with MOMA.Types;

with PolyORB.MOMA_P.Provider.Warehouse;

with PolyORB.Any.NVList;
with PolyORB.Exceptions;
with PolyORB.Log;
with PolyORB.Requests;
with PolyORB.Types;

package body PolyORB.MOMA_P.Provider.Message_Pool is

   use MOMA.Messages;

   use PolyORB.Any;
   use PolyORB.Any.NVList;
   use PolyORB.Log;
   use PolyORB.Requests;
   use PolyORB.Types;

   package L is new PolyORB.Log.Facility_Log ("moma.provider.message_pool");
   procedure O (Message : in Standard.String; Level : Log_Level := Debug)
     renames L.Output;

   --  Actual functions implemented by the servant.

   procedure Publish
     (Self    : access Object;
      Message : in     PolyORB.Any.Any);

   function Get
     (Self       : access Object;
      Message_Id : in     MOMA.Types.String)
     return PolyORB.Any.Any;

   procedure Register_Handler
     (Self        : access Object;
      Handler_Ref :        PolyORB.References.Ref;
      Behavior    :        MOMA.Types.Call_Back_Behavior);

   --  Accessors to servant interface.

   function Get_Parameter_Profile
     (Method : String)
     return PolyORB.Any.NVList.Ref;
   --  Parameters part of the interface description.

   ------------
   -- Invoke --
   ------------

   procedure Invoke
     (Self : access Object;
      Req  : in     PolyORB.Requests.Request_Access)
   is
      Args : PolyORB.Any.NVList.Ref;
      use PolyORB.Any.NVList.Internals;
      use PolyORB.Any.NVList.Internals.NV_Lists;
      use PolyORB.Exceptions;

      Error : Error_Container;
   begin
      pragma Debug (O ("The server is executing the request:"
                       & PolyORB.Requests.Image (Req.all)));

      Create (Args);

      if Req.Operation = To_PolyORB_String ("Publish") then

         --  Publish

         Add_Item (Args,
                   (Name      => To_PolyORB_String ("Message"),
                    Argument  => Get_Empty_Any (TC_MOMA_Message),
                    Arg_Modes => PolyORB.Any.ARG_IN));
         Arguments (Req, Args, Error);

         if Found (Error) then
            raise Program_Error;
            --  XXX We should do something more contructive

         end if;

         Publish (Self, Value (First (List_Of (Args).all)).Argument);

      elsif Req.Operation = To_PolyORB_String ("Get") then

         --  Get

         Add_Item (Args,
                   (Name => To_PolyORB_String ("Message_Id"),
                    Argument => Get_Empty_Any (TypeCode.TC_String),
                    Arg_Modes => PolyORB.Any.ARG_IN));
         Arguments (Req, Args, Error);

         if Found (Error) then
            raise Program_Error;
            --  XXX We should do something more contructive

         end if;

         Req.Result.Argument := Get
           (Self,
            PolyORB.Any.From_Any
            (Value (First (List_Of (Args).all)).Argument));
         pragma Debug (O ("Result: " & Image (Req.Result)));

      elsif Req.Operation = To_PolyORB_String ("Register_Handler") then

         --  Register Message call_back handler

         pragma Debug (O ("Register_Handler request"));
         Args := Get_Parameter_Profile (To_Standard_String (Req.Operation));

         PolyORB.Requests.Arguments (Req, Args, Error);

         if Found (Error) then
            raise Program_Error;
            --  XXX We should do something more contructive

         end if;


         declare
            It : Iterator := First (List_Of (Args).all);

            Handler_Dest, Behavior : Element_Access;
         begin
            Handler_Dest := Value (It);
            Next (It);
            Behavior     := Value (It);

            Register_Handler
              (Self,
               MOMA.Destinations.Get_Ref
               (MOMA.Destinations.From_Any (Handler_Dest.Argument)),
               MOMA.Types.Call_Back_Behavior'Value
               (MOMA.Types.To_Standard_String
                (MOMA.Types.From_Any (Behavior.Argument))));

            pragma Debug (O ("Registered message handler"));
         end;
      else
         pragma Debug (O ("Unrecognized request "
                          & To_Standard_String (Req.Operation)));
         raise Program_Error;
      end if;
   end Invoke;

   ---------------------------
   -- Get_Parameter_Profile --
   ---------------------------

   function Get_Parameter_Profile
     (Method : String)
     return PolyORB.Any.NVList.Ref
   is
      use PolyORB.Any;
      use PolyORB.Any.NVList;
      use PolyORB.Types;

      Result : PolyORB.Any.NVList.Ref;
   begin
      PolyORB.Any.NVList.Create (Result);
      pragma Debug (O ("Parameter profile for " & Method & " requested."));

      if Method = "Publish" then
         Add_Item (Result,
                   (Name => To_PolyORB_String ("Message"),
                    Argument => Get_Empty_Any (TC_MOMA_Message),
                    Arg_Modes => ARG_IN));

      elsif Method = "Get" then
         Add_Item (Result,
                   (Name => To_PolyORB_String ("Message_Id"),
                    Argument => Get_Empty_Any (TypeCode.TC_String),
                    Arg_Modes => ARG_IN));

      elsif Method = "Register_Handler" then
         Add_Item
           (Result,
            (Name => To_PolyORB_String ("Message_Handler"),
             Argument => Get_Empty_Any (MOMA.Destinations.TC_MOMA_Destination),
             Arg_Modes => ARG_IN));

         Add_Item (Result,
                   (Name => To_PolyORB_String ("Behavior"),
                    Argument => Get_Empty_Any (TypeCode.TC_String),
                    Arg_Modes => ARG_IN));

      else
         raise Program_Error;
      end if;

      return Result;
   end Get_Parameter_Profile;

   ------------------------------
   -- Servant actual functions --
   ------------------------------

   ----------------
   -- Initialize --
   ----------------

   procedure Initialize
     (Self : access Object;
      Info :        MOMA.Types.Message_Pool) is
   begin
      Self.Pool := Info;
      PolyORB.MOMA_P.Provider.Warehouse.Set_Persistence
        (Self.W,
         MOMA.Types.Get_Persistence (Info));

   end Initialize;

   -------------
   -- Publish --
   -------------

   procedure Publish
     (Self    : access Object;
      Message : in     PolyORB.Any.Any)
   is
      Temp : constant String := Integer'Image (Self.Message_Id);
      Key  : constant String := "M" & Temp (2 .. Temp'Last);
      --  Dummy Key construction, should be analyzed from message

      Rcvd_Message : MOMA.Messages.Message'Class := From_Any (Message);
      Id : constant String
        := MOMA.Types.To_Standard_String (Get_Message_Id (Rcvd_Message));

      use PolyORB.References;
      use MOMA.Types;
   begin
      if Self.Behavior = Handle
        and then Self.Message_Handler /= PolyORB.References.Nil_Ref
      then
         --  Send the message to the Message Call_Back Handler.
         --  Do not store the message locally.
         pragma Debug (O ("Got new message " & Image (Message)
                          & " with Id " & Key & ", forwarding to Message_"
                          & "Handler with Handle request"));
         declare
            Request     : PolyORB.Requests.Request_Access;
            Arg_List    : PolyORB.Any.NVList.Ref;
            Result      : PolyORB.Any.NamedValue;
         begin
            PolyORB.Any.NVList.Create (Arg_List);

            PolyORB.Any.NVList.Add_Item (Arg_List,
                                         To_PolyORB_String ("Message"),
                                         Message,
                                         PolyORB.Any.ARG_IN);
            Result :=
              (Name      => To_PolyORB_String ("Result"),
               Argument  => PolyORB.Any.Get_Empty_Any (PolyORB.Any.TC_Void),
               Arg_Modes => 0);

            PolyORB.Requests.Create_Request
              (Target    => Self.Message_Handler,
               Operation => "Handle",
               Arg_List  => Arg_List,
               Result    => Result,
               Req       => Request);

            PolyORB.Requests.Invoke (Request);

            PolyORB.Requests.Destroy_Request (Request);
         end;

      else

         if Id = "moma" then
            pragma Debug (O ("Got new message " & Image (Message)
                             & " with Id " & Key));
            Self.Message_Id := Self.Message_Id + 1;
            PolyORB.MOMA_P.Provider.Warehouse.Register (Self.W, Key, Message);

         else
            pragma Debug (O ("Got new message " & Image (Message)
                             & " with Id " & Id));
            PolyORB.MOMA_P.Provider.Warehouse.Register (Self.W, Id, Message);
         end if;

         if Self.Behavior = Notify
           and then Self.Message_Handler /= PolyORB.References.Nil_Ref
         then
            pragma Debug (O ("Forwarding to Message_Handler"
                             & " with Notify request"));
            --  Notify call_back Handler.
            --  The Message is stored locally.
            declare
               Request     : PolyORB.Requests.Request_Access;
               Arg_List    : PolyORB.Any.NVList.Ref;
               Result      : PolyORB.Any.NamedValue;
            begin
               PolyORB.Any.NVList.Create (Arg_List);

               Result :=
                 (Name      => To_PolyORB_String ("Result"),
                  Argument  => PolyORB.Any.Get_Empty_Any (PolyORB.Any.TC_Void),
                  Arg_Modes => 0);

               PolyORB.Requests.Create_Request
                 (Target    => Self.Message_Handler,
                  Operation => "Notify",
                  Arg_List  => Arg_List,
                  Result    => Result,
                  Req       => Request);

               PolyORB.Requests.Invoke (Request);

               PolyORB.Requests.Destroy_Request (Request);
            end;
         end if;

      end if;
   end Publish;

   ---------
   -- Get --
   ---------

   function Get
     (Self       : access Object;
      Message_Id : in     MOMA.Types.String)
     return PolyORB.Any.Any
   is
      Result : PolyORB.Any.Any;
      Temp : constant String := Integer'Image (Self.Last_Read_Id);
      Key  : constant String := "M" & Temp (2 .. Temp'Last);
      Id : constant String := MOMA.Types.To_Standard_String (Message_Id);

   begin
      if Id = "" then
         Result := PolyORB.MOMA_P.Provider.Warehouse.Lookup (Self.W, Key);
         PolyORB.MOMA_P.Provider.Warehouse.Unregister (Self.W, Key);
         Self.Last_Read_Id := Self.Last_Read_Id + 1;

         pragma Debug (O ("Sending back message " & Image (Result)
                          & " with id " & Key));
      else
         Result := PolyORB.MOMA_P.Provider.Warehouse.Lookup (Self.W, Key);
         pragma Debug (O ("Sending back message " & Image (Result)
                          & " with id " & Key));

      end if;

      return Result;
   end Get;

   ----------------------
   -- Register_Handler --
   ----------------------

   procedure Register_Handler
     (Self        : access Object;
      Handler_Ref :        PolyORB.References.Ref;
      Behavior    :        MOMA.Types.Call_Back_Behavior) is
   begin
      Self.Message_Handler := Handler_Ref;
      Self.Behavior := Behavior;
   end Register_Handler;

end PolyORB.MOMA_P.Provider.Message_Pool;