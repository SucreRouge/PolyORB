------------------------------------------------------------------------------
--                                                                          --
--                            GLADE COMPONENTS                              --
--                                                                          --
--           S Y S T E M . P A R T I T I O N _ I N T E R F A C E            --
--                                                                          --
--                                 S p e c                                  --
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

with System.RPC;

package System.Partition_Interface is

   pragma Elaborate_Body;

   type Subprogram_Id is new Natural;
   --  This type is used exclusively by stubs

   subtype Unit_Name is String;
   --  Name of Ada units

   function Get_Local_Partition_ID return RPC.Partition_ID;
   --  Return the Partition_ID of the current partition

   function Get_Active_Partition_ID
     (Name : Unit_Name)
      return RPC.Partition_ID;
   --  Similar in some respects to RCI_Info.Get_Active_Partition_ID

   function Get_Passive_Partition_ID
     (Name : Unit_Name)
     return RPC.Partition_ID;
   --  Return the Partition_ID of the given shared passive partition

   function Get_RCI_Package_Receiver
     (Name : Unit_Name)
      return RPC.RPC_Receiver;
   --  Similar in some respects to RCI_Info.Get_RCI_Package_Receiver

   function Get_Active_Version
      (Name : Unit_Name)
       return String;
   --  Similar in some respects to Get_Active_Partition_ID

   procedure Register_Receiving_Stub
     (Name     : in Unit_Name;
      Receiver : in RPC.RPC_Receiver;
      Version  : in String := "");
   --  Register the fact that the Name receiving stub is now elaborated.
   --  Register the access value to the package RPC_Receiver procedure.

   procedure Invalidate_Receiving_Stub
     (Name     : in Unit_Name);
   --  Declare this receiving stub as corrupted to the RCI Name Server

   generic
      RCI_Name : String;
   package RCI_Info is
      function Get_RCI_Package_Receiver return RPC.RPC_Receiver;
      function Get_Active_Partition_ID return RPC.Partition_ID;
   end RCI_Info;
   --  RCI package information caching

   type RACW_Stub_Type is tagged record
      Origin       : RPC.Partition_ID;
      Receiver     : RPC.RPC_Receiver;
      Addr         : System.Address;
      Asynchronous : Boolean;
   end record;
   type RACW_Stub_Type_Access is access RACW_Stub_Type;
   --  This type is used by the expansion to implement distributed objects.
   --  Do not change its definition or its layout without updating
   --  exp_dist.adb.

   procedure Get_Unique_Remote_Pointer
     (Handler : in out RACW_Stub_Type_Access);
   --  Get a unique pointer on a remote object

   procedure Raise_Program_Error_For_E_4_18;
   --  Raise Program_Error with an error message explaining why it has been
   --  raised. The rule in E.4 (18) is tricky and misleading for most users
   --  of the distributed systems annex.

end System.Partition_Interface;
