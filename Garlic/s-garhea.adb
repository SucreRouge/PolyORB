------------------------------------------------------------------------------
--                                                                          --
--                            GLADE COMPONENTS                              --
--                                                                          --
--                  S Y S T E M . G A R L I C . H E A R T                   --
--                                                                          --
--                                 B o d y                                  --
--                                                                          --
--                            $Revision$                             --
--                                                                          --
--         Copyright (C) 1996-1998 Free Software Foundation, Inc.           --
--                                                                          --
-- GARLIC is free software;  you can redistribute it and/or modify it under --
-- terms of the  GNU General Public License  as published by the Free Soft- --
-- ware Foundation;  either version 2,  or (at your option)  any later ver- --
-- sion.  GARLIC is distributed  in the hope that  it will be  useful,  but --
-- WITHOUT ANY WARRANTY;  without even the implied warranty of MERCHANTABI- --
-- LITY or  FITNESS FOR A PARTICULAR PURPOSE.  See the  GNU General Public  --
-- License  for more details.  You should have received  a copy of the GNU  --
-- General Public License  distributed with GARLIC;  see file COPYING.  If  --
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
--               GLADE  is maintained by ACT Europe.                        --
--               (email: glade-report@act-europe.fr)                        --
--                                                                          --
------------------------------------------------------------------------------

with Ada.Exceptions;                  use Ada.Exceptions;
pragma Warnings (Off, Ada.Exceptions);
with System.Garlic.Debug;             use System.Garlic.Debug;
with System.Garlic.Filters;           use System.Garlic.Filters;
with System.Garlic.Name_Table;        use System.Garlic.Name_Table;
with System.Garlic.Options;
with System.Garlic.Partitions;        use System.Garlic.Partitions;
with System.Garlic.Physical_Location; use System.Garlic.Physical_Location;
with System.Garlic.Protocols;         use System.Garlic.Protocols;
with System.Garlic.Soft_Links;        use System.Garlic.Soft_Links;
with System.Garlic.Streams;           use System.Garlic.Streams;
with System.Garlic.Trace;             use System.Garlic.Trace;
with System.Garlic.Types;             use System.Garlic.Types;
with System.Garlic.Utils;
with System.Standard_Library;

with System.Garlic.Linker_Options;
pragma Warnings (Off, System.Garlic.Linker_Options);

package body System.Garlic.Heart is

   use Ada.Streams;
   use System.Garlic.Types, System.Garlic.Utils;
   use System.Garlic.Partitions.Complex;

   Partitions_Table : Complex.Component_Table_Access renames Complex.Table;

   Private_Debug_Key : constant Debug_Key :=
     Debug_Initialize ("S_GARHEA", "(s-garhea): ");

   procedure D
     (Level   : in Debug_Level;
      Message : in String;
      Key     : in Debug_Key := Private_Debug_Key)
     renames Print_Debug_Info;

   Shutdown_Policy     : Shutdown_Type     := Shutdown_On_Boot_Partition_Error;
   --  These parameters control how Garlic will act in face of errors.
   --  They don't need extra protection because they should not be modified
   --  by more than one task (in fact, they should not be modified after
   --  the elaboration is terminated).

   Elaboration_Barrier : Barrier_Type;
   --  This barrier will be no longer blocking when the elaboration is
   --  terminated.

   procedure Handle_Internal
     (Partition : in Partition_ID;
      Operation : in Internal_Opcode;
      Params    : access Params_Stream_Type);
   --  Internal operations

   procedure Handle_Public
     (Partition : in Partition_ID;
      Operation : in Public_Opcode;
      Params    : access Params_Stream_Type);
   --  Public operations

   function Get_Partition_Info
     (Partition : Partition_ID)
      return Partition_Info;
   --  If cached, then return local partition info. Otherwise, on a non
   --  boot partition send a request. Wait for info to be available.

   function Get_Protocol
     (Partition : Partition_ID)
      return Protocol_Access;
   pragma Inline (Get_Protocol);
   --  Same as above. But for boot partition, then get protocol from
   --  boot server option.

   function Opcode_Read (Operation : Stream_Element) return Opcode;
   pragma Inline (Opcode_Read);
   function Opcode_Write (Operation : Opcode) return Stream_Element;
   pragma Inline (Opcode_Write);
   --  Read and write opcode on one byte

   procedure Partition_Info_Receiver
     (Partition : in Partition_ID;
      Params    : access Params_Stream_Type);
   --  Handle Partition_Service operations

   procedure Process
     (PID       : in Partition_ID;
      Request   : in Request_Type;
      Partition : in out Partition_Info;
      Status    : out Status_Type);
   --  Execute Request on Partition. This procedure is used by
   --  Apply to get an atomic operation. The request can be postponed
   --  when Status is set to Postponed. In this case, Process will
   --  re-executed when the shared data status is set to Modified.

   procedure Send
     (Target    : in Partition_ID;
      Request   : in Request_Type;
      Partition : in Partition_ID);
   --  Send to Target a Request on Partition

   Self_PID_Barrier : Barrier_Access := new Barrier_Type;
   --  Block any task until Self_PID is different from Null_PID

   Receiver_Map : array (Public_Opcode) of Public_Receiver;
   --  Receiver callbacks table

   procedure Shutdown;
   --  Generates a local shutdown

   Partition_Error_Notification : RPC_Error_Notifier_Type;
   --  Call this procedure when a partition dies

   procedure Partition_RPC_Receiver
     (Params : access Streams.Params_Stream_Type;
      Result : access Streams.Params_Stream_Type);
   --  Global RPC receiver

   procedure Dump_Partition_Info
     (PID  : in Partition_ID;
      Info : in Partition_Info);
   --  Dump a summary of all the information we have on a partition

   function PID_Read (Partition : Stream_Element) return Partition_ID;
   pragma Inline (PID_Read);
   function PID_Write (Partition : Partition_ID) return Stream_Element;
   pragma Inline (PID_Write);
   --  Read and write partition id on one byte

   ------------------
   -- Allocate_PID --
   ------------------

   function Allocate_PID return Partition_ID is
      Partition : Partition_ID;
   begin
      Enter_Critical_Section;
      for P in Partitions_Table'Range loop
         if not Partitions_Table (P).Allocated then
            Partitions_Table (P).Allocated := True;
            Partition := P;
            exit;
         end if;
      end loop;
      Leave_Critical_Section;
      pragma Debug (D (D_Server, "Allocating partition" & Partition'Img));
      return Partition;
   end Allocate_PID;

   --------------------
   -- Analyze_Stream --
   --------------------

   procedure Analyze_Stream
     (Partition  : out Partition_ID;
      Operation  : out Opcode;
      Unfiltered : out Stream_Element_Access;
      Filtered   : in  Stream_Element_Access;
      Offset     : in  Ada.Streams.Stream_Element_Count := 0)
   is
      PID   : Partition_ID;
      Code  : Opcode;
      First : constant Stream_Element_Count := Filtered'First + Offset;
      Last  : constant Stream_Element_Count := Filtered'Last;
      Data  : Stream_Element_Array renames Filtered (First + 2 .. Last);
   begin
      --  Dump the stream for debugging purpose

      pragma Debug (D (D_Dump, "Dumping incoming stream"));
      pragma Debug (Dump (D_Dump, Filtered, Private_Debug_Key));

      --  Record the current packet content in the trace file if needed

      if Options.Execution_Mode = Trace_Mode then
         Trace_Data (Partition, Filtered);
      end if;

      --  Read the partition id from the stream and check that it is valid

      PID := PID_Read (Filtered (First));
      if not PID'Valid then
         pragma Debug (D (D_Debug, "Received incorrect partition id"));
         raise Constraint_Error;
      end if;

      --  Read the opcode from the stream and check that it is valid

      Code := Opcode_Read (Filtered (First + 1));
      if not Code'Valid then
         pragma Debug (D (D_Debug, "Received unknown opcode"));
         raise Constraint_Error;
      elsif Code = No_Operation then
         pragma Debug (D (D_Debug, "Received No_Operation opcode"));
         raise Constraint_Error;
      end if;

      --  When the partition id is unknown, allocate a new one

      if PID = Null_PID then
         PID := Allocate_PID;
      end if;

      pragma Debug
        (D (D_Debug,
            "Received request with opcode " & Code'Img &
            " from partition" & PID'Img));

      --  Unfilter the data and put it in a stream

      Unfiltered := Filter_Incoming (PID, Code, Data);
      Partition  := PID;
      Operation  := Code;

   exception when others =>
      pragma Debug (D (D_Debug, "Exception in block Analyze_Stream"));
      raise;
   end Analyze_Stream;

   ------------------------
   -- Blocking_Partition --
   ------------------------

   function Blocking_Partition (Partition : Partition_ID) return Boolean is
      Data : constant Partition_Info := Get_Component (Partition);
   begin
      return Data.Termination = Local_Termination
        and then Data.Status = Defined;
   end Blocking_Partition;

   ------------------------------
   -- Can_Have_A_Light_Runtime --
   ------------------------------

   function Can_Have_A_Light_Runtime return Boolean is
   begin
      --  If the termination is not Local_Termination, fail

      if Options.Termination /= Local_Termination then
         return False;
      end if;

      --  If there is any RCI or RACW package, fail

      if Options.Has_RCI_Pkg_Or_RACW_Var then
         return False;
      end if;

      --  If this is the main partition, fail

      if Options.Boot_Partition then
         return False;
      end if;

      --  There is no reason not to have a light runtime

      return True;
   end Can_Have_A_Light_Runtime;

   --------------------------
   -- Complete_Elaboration --
   --------------------------

   procedure Complete_Elaboration is
   begin
      pragma Debug
        (D (D_Elaborate, "Signaling that elaboration is terminated"));
      Elaboration_Barrier.Signal_All (Permanent => True);
   end Complete_Elaboration;

   -------------------------
   -- Dump_Partition_Info --
   -------------------------

   procedure Dump_Partition_Info
     (PID  : in Partition_ID;
      Info : in Partition_Info)
   is
   begin
      D (D_Dump, "Information on partition" & Partition_ID'Image (PID));
      if Info.Logical_Name /= null then
         D (D_Dump, "  Name:         " & Info.Logical_Name.all);
      else
         D (D_Dump, "  Name:         <no name>");
      end if;
      D (D_Dump, "  Location:     " & To_String (Info.Location));
      D (D_Dump, "  Termination:  " & Info.Termination'Img);
      D (D_Dump, "  Reconnection: " & Info.Reconnection'Img);
      D (D_Dump, "  Status:       " & Partition_Status'Image (Info.Status));
   end Dump_Partition_Info;

   ---------------------
   -- Get_Boot_Server --
   ---------------------

   function Get_Boot_Server return String is
      Info : Partition_Info;
   begin
      Info := Get_Component (Boot_PID);
      return To_String (Info.Location);
   end Get_Boot_Server;

   -------------------------
   -- Get_My_Partition_ID --
   -------------------------

   function Get_My_Partition_ID return Partition_ID is
      Set  : Request_Type (Set_Partition_Info);
      Info : Partition_Info;
   begin
      if Self_PID = Null_PID then

         --  Self_PID is unknown. Use Last_PID as a temporary partition id.
         --  Fill partition info with Garlic.Options info.

         Info := Get_Component (Last_PID);
         Set.Logical_Name := Options.Partition_Name;
         Set.Location     := Info.Location;
         Set.Termination  := Options.Termination;
         Set.Reconnection := Options.Reconnection;

         if Options.Boot_Partition then
            Apply (Boot_PID, Set, Process'Access);
            Set_My_Partition_ID (Boot_PID);

         else
            --  We will send a Set_Partition_Info request to the server.
            --  This will cause a dialog to be established and a new
            --  Partition_ID to be allocated, and our location will be
            --  registered into the boot partition's base. The boot
            --  partition sends partition info on itself to this partition.
            --  Then, it sends partition info on this partition. Therefore,
            --  the current partition id is known and Self_PID_Barrier will
            --  be kept opened.

            Apply (Last_PID, Set, Process'Access);
            Self_PID_Barrier.Wait;

         end if;
      end if;

      return Self_PID;
   exception
      when E : others =>
         pragma Warnings (Off, E);
         pragma Debug (D (D_Debug, Exception_Information (E)));
         raise;
   end Get_My_Partition_ID;

   ------------------------
   -- Get_Partition_Info --
   ------------------------

   function Get_Partition_Info (Partition : Partition_ID)
      return Partition_Info is
   begin
      --  If partition info is availablein the cache, then get it from
      --  there. Otherwise, send a request to boot partition to update
      --  the cache.

      if Partitions_Table (Partition).Status /= Defined then
         pragma Debug
           (D (D_Table, "Looking for info on partition" & Partition'Img));

         Apply (Partition, (Get_Partition_Info, Self_PID), Process'Access);
      end if;

      return Partitions_Table (Partition);
   end Get_Partition_Info;

   ------------------
   -- Get_Protocol --
   ------------------

   function Get_Protocol (Partition : Partition_ID) return Protocol_Access is
   begin
      --  If the partition is the boot server, then the protocol is
      --  already known even when Partition_Info is only partially
      --  initialized.

      if Partition /= Boot_PID
        and then Partitions_Table (Partition).Status /= Defined
      then
         return Get_Partition_Info (Partition).Protocol;
      end if;

      return Partitions_Table (Partition).Protocol;
   end Get_Protocol;

   -----------------------
   -- Get_Self_Location --
   -----------------------

   function Get_Self_Location return Location_Type is
      P : Partition_ID := Self_PID;
   begin
      --  If Self_PID is not initialized, then the location is supposed
      --  to be stored temporary in the Last_PID slot.

      if P = Null_PID then
         P := Last_PID;
      end if;
      return Get_Component (P).Location;
   end Get_Self_Location;

   ---------------------
   -- Handle_Internal --
   ---------------------

   procedure Handle_Internal
     (Partition : in Partition_ID;
      Operation : in Internal_Opcode;
      Params    : access Params_Stream_Type)
   is
   begin
      Soft_Links.Activity_Detected;

      case Operation is
         when No_Operation =>
            null;

         when Partition_Service =>
            Partition_Info_Receiver (Partition, Params);

         when Shutdown =>
            pragma Debug
              (D (D_Garlic,
                  "Receive shutdown request from partition" & Partition'Img));

            Heart.Shutdown;

      end case;

   exception
      when E : others =>
         pragma Warnings (Off, E);
         pragma Debug (D (D_Garlic, "Handle_Internal: fatal exception"));
         pragma Debug (D (D_Debug, Exception_Information (E)));
         raise Communication_Error;
   end Handle_Internal;

   -------------------
   -- Handle_Public --
   -------------------

   procedure Handle_Public
     (Partition : in Partition_ID;
      Operation : in Public_Opcode;
      Params    : access Params_Stream_Type)
   is
      Receiver : Public_Receiver;
   begin
      pragma Assert (Self_PID /= Null_PID);

      if Operation /= Shutdown_Synchronization then
         Soft_Links.Activity_Detected;
      end if;

      Receiver := Receiver_Map (Operation);
      pragma Assert (Receiver /= null);

      Receiver (Partition, Operation, Params);
   exception
      when E : others =>
         pragma Warnings (Off, E);
         pragma Debug (D (D_Garlic, "Handle_Public: fatal exception"));
         pragma Debug (D (D_Debug, Exception_Information (E)));
         raise Communication_Error;
   end Handle_Public;

   ----------------
   -- Initialize --
   ----------------

   procedure Initialize is
   begin
      pragma Debug
        (D (D_Dump,
            "My partition name is " & Options.Partition_Name.all));
      pragma Debug
        (D (D_Dump,
            "My termination policy is " & Options.Termination'Img));
      pragma Debug
        (D (D_Dump,
            "My reconnection policy is " & Options.Reconnection'Img));
      null;
   end Initialize;

   ------------------------
   -- Last_Allocated_PID --
   ------------------------

   function Last_Allocated_PID return Partition_ID is
   begin
      for P in reverse Partitions_Table'Range loop
         if Partitions_Table (P).Allocated then
            return P;
         end if;
      end loop;
      return Null_PID;
   end Last_Allocated_PID;

   --------------
   -- Location --
   --------------

   function Location (Partition : Partition_ID) return Location_Type is
   begin
      return Get_Component (Partition) .Location;
   end Location;

   ----------
   -- Name --
   ----------

   function Name (Partition : Partition_ID) return Name_Id is
   begin
      return Get (Name (Partition));
   end Name;

   ----------
   -- Name --
   ----------

   function Name (Partition : Partition_ID) return String is
   begin
      return Get_Partition_Info (Partition).Logical_Name.all;
   end Name;

   -----------------
   -- Opcode_Read --
   -----------------

   function Opcode_Read (Operation : Stream_Element) return Opcode is
   begin
      return Opcode'Val (Operation);
   end Opcode_Read;

   ------------------
   -- Opcode_Write --
   ------------------

   function Opcode_Write (Operation : Opcode) return Stream_Element is
   begin
      return Opcode'Pos (Operation);
   end Opcode_Write;

   --------------
   -- PID_Read --
   --------------

   function PID_Read (Partition : Stream_Element) return Partition_ID is
   begin
      return Partition_ID (Partition);
   end PID_Read;

   ---------------
   -- PID_Write --
   ---------------

   function PID_Write (Partition : Partition_ID) return Stream_Element is
   begin
      return Stream_Element (Partition);
   end PID_Write;

   -----------------------------
   -- Partition_Info_Receiver --
   -----------------------------

   procedure Partition_Info_Receiver
     (Partition : in Partition_ID;
      Params    : access Params_Stream_Type)
   is
      Request : Request_Type;
      PID     : Partition_ID;
      Boot    : Boolean := False;
   begin
      --  Do not answer to any request until boot partition completes
      --  its initialization (ie initializes its partition id).

      if Options.Boot_Partition and then Self_PID = Null_PID then
         Self_PID_Barrier.Wait;
      end if;

      Partition_ID'Read (Params, PID);
      Request := Request_Type'Input (Params);

      pragma Debug
        (D (D_Warning,
            "Receive from partition" & Partition'Img &
            " a request " & Request.Kind'Img &
            " on partition " & PID'Img));

      if Request.Kind = Set_Partition_Info then
         --  A Set_Partition_Info request is a qrequest sent by a partition
         --  during its elaboration in order to get a partition id. On
         --  the boot partition, indicate that this partition is in a
         --  boot phase.

         if Options.Boot_Partition then
            PID  := Partition;
            Boot := True;
         end if;

         if Options.Execution_Mode = Replay_Mode then
            Request.Location := To_Location ("replay://");
         end if;
      end if;

      --  Run Process in an exclusive and unabortable procedure

      pragma Debug (D (D_Debug, "Request to apply"));
      Apply (PID, Request, Process'Access);
      pragma Debug (D (D_Debug, "Request applied"));

      --  If the remote partition is in a boot phase, send to this
      --  partition the boot partition info and then its partition info.
      --  This will allow the remote partition to get its partition id.

      if Boot then
         declare
            Set  : Request_Type;
            Info : Partition_Info;
         begin
            Info := Get_Component (Boot_PID);
            Set  := (Set_Partition_Info,
                     Info.Logical_Name,
                     Info.Location,
                     Info.Termination,
                     Info.Reconnection);
            Send (PID, Set, Boot_PID);

            Info := Get_Component (PID);
            Set  := (Set_Partition_Info,
                     Info.Logical_Name,
                     Info.Location,
                     Info.Termination,
                     Info.Reconnection);
            Send (PID, Set, PID);
         end;
      end if;

      --  If we receive a request from boot partition and then the partition
      --  id of the current partition is unknown and then the info does
      --  not concern to boot partition, then this info concerns the current
      --  partition. The request provides the new partition id.

      if Partition = Boot_PID
        and then Self_PID = Null_PID
        and then PID     /= Boot_PID
      then
         Set_My_Partition_ID (PID);
      end if;
   end Partition_Info_Receiver;

   ----------------------------
   -- Partition_RPC_Receiver --
   ----------------------------

   procedure Partition_RPC_Receiver
     (Params : access Streams.Params_Stream_Type;
      Result : access Streams.Params_Stream_Type)
   is
      Receiver : RPC_Receiver;
   begin
      RPC_Receiver'Read (Params, Receiver);
      Receiver (Params, Result);
   end Partition_RPC_Receiver;

   -------------
   -- Process --
   -------------

   procedure Process
     (PID       : in Partition_ID;
      Request   : in Request_Type;
      Partition : in out Partition_Info;
      Status    : out Status_Type) is
   begin
      pragma Debug
        (D (D_Warning,
            "Process " & Request.Kind'Img & " on partition" & PID'Img));
      pragma Debug
        (D (D_Warning,
            "Partition status " & Partition.Status'Img));

      case Request.Kind is
         when Get_Partition_Info =>
            case Partition.Status is
               when Undefined =>
                  --  Change status and send request to boot partition

                  Partition.Status := Queried;
                  if not Options.Boot_Partition then
                     Send (Boot_PID, Request, PID);
                  end if;

                  --  Wait for a reply

                  Status := Postponed;

               when Queried =>
                  --  Wait for a reply

                  Status := Postponed;

               when Defined =>
                  --  If this is a remote request then send the
                  --  reply to the remote partition.

                  if Request.Reply_To_PID /= Self_PID then
                     declare
                        Set : Request_Type (Set_Partition_Info);
                     begin
                        Set.Logical_Name := Partition.Logical_Name;
                        Set.Location     := Partition.Location;
                        Set.Termination  := Partition.Termination;
                        Set.Reconnection := Partition.Reconnection;
                        Send (Request.Reply_To_PID, Set, PID);
                     end;
                  end if;
                  Status := Unmodified;

            end case;

         when Set_Partition_Info =>
            case Partition.Status is
               when Undefined =>
                  --  If this request is received by the boot partition
                  --  or if PID is different from Last_PID (ie was not
                  --  built locally), then really set info.

                  if Options.Boot_Partition or else PID /= Last_PID then
                     Partition.Logical_Name := Request.Logical_Name;
                     Partition.Location     := Request.Location;
                     Partition.Termination  := Request.Termination;
                     Partition.Reconnection := Request.Reconnection;

                     Partition.Protocol := Get_Protocol (Partition.Location);
                     Partition.Status   := Defined;

                  else
                     --  This request was built locally. It excepts a
                     --  reply from boot partition. Set Status to Queried
                     --  and send request to boot partition. Wait for the
                     --  reply.

                     Partition.Status       := Queried;
                     Send (Boot_PID, Request, PID);
                  end if;
                  Status := Modified;

               when Queried | Defined =>
                  Partition.Logical_Name := Request.Logical_Name;
                  Partition.Location     := Request.Location;
                  Partition.Termination  := Request.Termination;
                  Partition.Reconnection := Request.Reconnection;

                  Partition.Protocol := Get_Protocol (Partition.Location);
                  Partition.Status   := Defined;
                  Status := Modified;

            end case;
      end case;
   end Process;

   --------------------
   -- Process_Stream --
   --------------------

   procedure Process_Stream
     (Partition  : in Partition_ID;
      Operation  : in Opcode;
      Unfiltered : in Stream_Element_Access)
   is
      Stream : aliased Params_Stream_Type (Unfiltered.all'Length);
   begin
      --  Dump the stream for debugging purpose

      pragma Debug (D (D_Dump, "Dumping incoming stream"));
      pragma Debug (Dump (D_Dump, Unfiltered, Private_Debug_Key));

      To_Params_Stream_Type (Unfiltered.all, Stream'Access);

      --  Depending on the opcode, dispatch to the public or internal routines.

      case Operation is
         when Internal_Opcode =>
            Handle_Internal (Partition, Operation, Stream'Access);
         when Public_Opcode   =>
            Handle_Public (Partition, Operation, Stream'Access);
         when Invalid_Operation =>
            raise Program_Error;
      end case;

   exception when others =>
      pragma Debug (D (D_Debug, "Exception in block Process_Stream"));
      raise;
   end Process_Stream;

   -------------
   -- Receive --
   -------------

   procedure Receive (Operation : in Opcode; Receiver : in Public_Receiver) is
   begin
      pragma Debug
        (D (D_Garlic,
            "Receiver for operation " & Operation'Img & " is now registered"));

      Receiver_Map (Operation) := Receiver;
   end Receive;

   -------------------------
   -- Reconnection_Policy --
   -------------------------

   function Reconnection_Policy
     (Partition : Partition_ID)
      return Reconnection_Type is
   begin
      return Get_Component (Partition) .Reconnection;
   end Reconnection_Policy;

   -------------------------------------------
   -- Register_Partition_Error_Notification --
   -------------------------------------------

   procedure Register_Partition_Error_Notification
     (Callback : in RPC_Error_Notifier_Type) is
   begin
      Partition_Error_Notification := Callback;
   end Register_Partition_Error_Notification;

   ----------------------------
   -- Remote_Partition_Error --
   ----------------------------

   procedure Remote_Partition_Error
     (Partition : in Partition_ID)
   is
      Info : Partition_Info;
   begin
      pragma Debug
        (D (D_Communication,
            "It looks like partition" & Partition'Img & " is dead"));
      Info := Get_Component (Partition);
      Info.Status := Undefined;
      Set_Component (Partition, Info);
      if Shutdown_Policy = Shutdown_On_Any_Partition_Error then
         pragma Debug
            (D (D_Communication, "Due to the policy, I will shutdown"));
         Soft_Shutdown;
      end if;
      if Partition = Boot_PID and then
        Shutdown_Policy = Shutdown_On_Boot_Partition_Error then
         pragma Debug
           (D (D_Communication, "I cannot live without a boot partition"));
         Soft_Shutdown;
      end if;
      if Partition_Error_Notification /= null then
         pragma Debug (D (D_Debug, "Calling the registered callback"));
         Partition_Error_Notification (Partition);
      end if;
   end Remote_Partition_Error;

   ----------
   -- Send --
   ----------

   procedure Send
     (Partition : in Partition_ID;
      Operation : in Opcode;
      Params    : access Params_Stream_Type)
   is
      Filtered : Stream_Element_Access;
      Length   : Stream_Element_Offset;
      Stream   : Stream_Element_Access;
   begin
      pragma Debug
        (D (D_Debug, "Send " & Operation'Img & " message to" & Partition'Img));

      --  Filter the data according to the remote partition and the opcode

      Filtered := Filter_Outgoing (Partition, Operation, Params);

      --  Workaround: XXXXX (Bad code generation on Solaris)
      if Filtered = null then
         raise Program_Error;
      end if;

      --  Compute the length of the packet: this is the length of the
      --  unused space that will be used by the protocol to stick its own
      --  data at the beginning + 1 for the opcode + 1 for partition id +
      --  the length of the unfiltered data. Allocate a packet of the right
      --  length.

      Length := Unused_Space + 2 + Filtered'Length;
      Stream := new Stream_Element_Array (1 .. Length);

      --  Put the opcode and the partition id at the beginning of
      --  the reserved section, then the filtered data, which can then
      --  be deallocated.

      Stream (Unused_Space + 1) := PID_Write (Self_PID);
      Stream (Unused_Space + 2) := Opcode_Write (Operation);
      Stream (Unused_Space + 3 .. Stream'Last) := Filtered.all;
      Free (Filtered);

      --  If the data is for a remote partition, send it using the right
      --  protocol. Otherwise, make local calls (this can happen for a call
      --  on which pragma All_Calls_Remote applies) without extra space.

      if Partition = Self_PID then
         pragma Debug (D (D_Debug, "Handling a All_Calls_Remote case"));
         declare
            PID        : Partition_ID;
            Code       : Opcode;
            Unfiltered : Stream_Element_Access;
         begin
            Analyze_Stream (PID, Code, Unfiltered, Stream, Unused_Space);
            Process_Stream (PID, Code, Unfiltered);
            Free (Unfiltered);
         exception when others =>
            Free (Unfiltered);
         end;
      else
         pragma Debug (D (D_Debug, "Calling the right protocol"));
         Send (Get_Protocol (Partition), Partition, Stream);
      end if;

      --  Free the data, even if an exception occurs

      Free (Stream);

   exception when others =>
      Free (Stream);
      Free (Filtered);
      raise;
   end Send;

   ----------
   -- Send --
   ----------

   procedure Send
     (Target    : in Partition_ID;
      Request   : in Request_Type;
      Partition : in Partition_ID)
   is
      Params : aliased Params_Stream_Type (0);
   begin
      pragma Debug
        (D (D_Warning,
            "send to partition" & Target'Img &
            " a request " & Request.Kind'Img &
            " on partition" & Partition'Img));
      Partition_ID'Write (Params'Access, Partition);
      Request_Type'Output (Params'Access, Request);
      Send (Target, Partition_Service, Params'Access);
   end Send;

   -----------------------
   -- Set_Boot_Location --
   -----------------------

   procedure Set_Boot_Location
     (Location : in Location_Type)
   is
      Info : Partition_Info :=
        (Allocated    => True,
         Location     => Location,
         Protocol     => Get_Protocol (Location),
         Logical_Name => null,
         Reconnection => Rejected_On_Restart,
         Termination  => Global_Termination,
         Status       => Defined);
   begin
      if Options.Boot_Partition then
         Info.Logical_Name := Options.Partition_Name;
      end if;

      pragma Debug
        (D (D_Debug,
            "Configuring boot location to be " & To_String (Location)));

      Set_Component (Boot_PID, Info);
   end Set_Boot_Location;

   -------------------------
   -- Set_My_Partition_ID --
   -------------------------

   procedure Set_My_Partition_ID (Partition : in Partition_ID) is
   begin
      pragma Debug
        (D (D_Debug, "Got my partition ID, I am partition" & Partition'Img));

      --  Set this so that exception informations contain the Partition_ID

      System.Standard_Library.Local_Partition_ID := Natural (Partition);

      --  Save partition id and signal update of this variable

      Self_PID := Partition;
      Self_PID_Barrier.Signal_All (Permanent => True);
   end Set_My_Partition_ID;

   ----------------
   -- Set_Policy --
   ----------------

   procedure Set_Policy
     (Shutdown : Shutdown_Type := Shutdown_On_Boot_Partition_Error)
   is
   begin
      Shutdown_Policy := Shutdown;
   end Set_Policy;

   -----------------------
   -- Set_Self_Location --
   -----------------------

   procedure Set_Self_Location
     (Location : in Location_Type)
   is
      PID  : Partition_ID := Self_PID;
      Info : Partition_Info;
   begin
      pragma Debug
        (D (D_Debug, "Setting my location to " & To_String (Location)));

      if PID = Null_PID then
         PID := Last_PID;
      end if;
      Info := Get_Component (PID);
      Info.Location := Location;
      Set_Component (PID, Info);
   end Set_Self_Location;

   --------------
   -- Shutdown --
   --------------

   procedure Shutdown is
   begin
      Shutdown_In_Progress := True;
      Trace.Shutdown;
      Soft_Links.Termination_Shutdown;
      Physical_Location.Shutdown;
      RPC_Shutdown;
      Free (Self_PID_Barrier);
      Delete_Termination_Sanity_File;
   end Shutdown;

   -------------------
   -- Soft_Shutdown --
   -------------------

   procedure Soft_Shutdown is
   begin
      Shutdown_In_Progress := True;
      if Options.Boot_Partition then
         for Partition in Boot_PID + 1 .. Last_Allocated_PID loop
            if Termination_Policy (Partition) /= Local_Termination then
               declare
                  Empty : aliased Params_Stream_Type (0);
               begin
                  Send (Partition, Shutdown, Empty'Access);
               exception
                  when Communication_Error => null;
               end;
            end if;
         end loop;
      end if;
      Heart.Shutdown;
   end Soft_Shutdown;

   ------------------------
   -- Termination_Policy --
   ------------------------

   function Termination_Policy (Partition : Partition_ID)
     return Termination_Type is
   begin
      return Get_Component (Partition) .Termination;
   end Termination_Policy;

   ------------------------------------------
   -- Wait_Until_Elaboration_Is_Terminated --
   ------------------------------------------

   procedure Wait_Until_Elaboration_Is_Terminated is
   begin
      pragma Debug
        (D (D_Debug, "Checking that elaboration is terminated"));

      Elaboration_Barrier.Wait;

      pragma Debug
         (D (D_Debug, "Confirmation that elaboration is terminated"));
   end Wait_Until_Elaboration_Is_Terminated;

end System.Garlic.Heart;
