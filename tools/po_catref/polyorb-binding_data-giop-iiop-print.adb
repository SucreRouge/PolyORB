------------------------------------------------------------------------------
--                                                                          --
--                           POLYORB COMPONENTS                             --
--                                                                          --
--                  POLYORB.BINDING_DATA.GIOP.IIOP.PRINT                    --
--                                                                          --
--                                 B o d y                                  --
--                                                                          --
--         Copyright (C) 2004-2017, Free Software Foundation, Inc.          --
--                                                                          --
-- This is free software;  you can redistribute it  and/or modify it  under --
-- terms of the  GNU General Public License as published  by the Free Soft- --
-- ware  Foundation;  either version 3,  or (at your option) any later ver- --
-- sion.  This software is distributed in the hope  that it will be useful, --
-- but WITHOUT ANY WARRANTY;  without even the implied warranty of MERCHAN- --
-- TABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public --
-- License for  more details.                                               --
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

with PO_Catref.Common;
with PO_Catref.Output;

with PolyORB.Binding_Data.Print;
with PolyORB.Initialization;

with PolyORB.GIOP_P.Tagged_Components.Print;
with PolyORB.GIOP_P.Transport_Mechanisms.IIOP;
with PolyORB.GIOP_P.Tagged_Components.SSL_Sec_Trans.Print;
with PolyORB.Sockets;
with PolyORB.Types; use PolyORB.Types;
with PolyORB.Utils.Sockets;
with PolyORB.Utils.Strings;

package body PolyORB.Binding_Data.GIOP.IIOP.Print is

   use PolyORB.GIOP_P.Tagged_Components;
   use PolyORB.GIOP_P.Tagged_Components.SSL_Sec_Trans;
   use PolyORB.GIOP_P.Tagged_Components.SSL_Sec_Trans.Print;
   use PolyORB.GIOP_P.Transport_Mechanisms.IIOP;
   use PolyORB.Sockets;

   function Get_Primary_IIOP_Address
     (Prof : IIOP_Profile_Type)
      return Utils.Sockets.Socket_Name;

   ------------------------------
   -- Get_Primary_IIOP_Address --
   ------------------------------

   function Get_Primary_IIOP_Address
     (Prof : IIOP_Profile_Type)
      return Utils.Sockets.Socket_Name
   is
   begin
      return
        Primary_Address_Of
        (IIOP_Transport_Mechanism
         (Get_Primary_Transport_Mechanism (Prof).all));
   end Get_Primary_IIOP_Address;

   ------------------------
   -- Print_IIOP_Profile --
   ------------------------

   procedure Print_IIOP_Profile (Prof : Profile_Access) is
      use PO_Catref.Common;
      use PO_Catref.Output;

      use PolyORB.GIOP_P.Tagged_Components.Print;

      IIOP_Prof : IIOP_Profile_Type renames IIOP_Profile_Type (Prof.all);
      SSL_TC    : constant Tagged_Component_Access
        := Get_Component (IIOP_Prof, Tag_SSL_Sec_Trans);

   begin
      Inc_Indent;

      if SSL_TC = null then
         Put_Line ("IIOP Version",
                   Trimmed_Image (Unsigned_Long_Long (IIOP_Prof.Version_Major))
                   & "." &
                   Trimmed_Image (Unsigned_Long_Long
                                  (IIOP_Prof.Version_Minor)));

         Output_Address_Information (Get_Primary_IIOP_Address (IIOP_Prof));

      else
         Put_Line ("IIOP/SSLIOP Version",
                   Trimmed_Image (Unsigned_Long_Long (IIOP_Prof.Version_Major))
                   & "." &
                   Trimmed_Image (Unsigned_Long_Long
                                  (IIOP_Prof.Version_Minor)));

         if Get_Primary_IIOP_Address (IIOP_Prof).Port /= 0 then
            Put_Line ("Unprotected invocations", "");
            Output_Address_Information (Get_Primary_IIOP_Address (IIOP_Prof));

         else
            Put_Line ("Unprotected invocations", "Not Supported");
         end if;

         Put_Line ("Protected invocations", "");

         Output_TC
           (TC_SSL_Sec_Trans (SSL_TC.all),
            Get_Primary_IIOP_Address (IIOP_Prof));
      end if;

      Output_Object_Information (IIOP_Prof.Object_Id.all);

      Output_Tagged_Components (IIOP_Prof.Components);

      Dec_Indent;
   end Print_IIOP_Profile;

   ----------------
   -- Initialize --
   ----------------

   procedure Initialize;

   procedure Initialize is
   begin
      PolyORB.Binding_Data.Print.Register
        (Tag_Internet_IOP, Print_IIOP_Profile'Access);
   end Initialize;

   use PolyORB.Initialization;
   use PolyORB.Initialization.String_Lists;
   use PolyORB.Utils.Strings;

begin
   Register_Module
     (Module_Info'
      (Name      => +"polyorb.binding_data.iiop.print",
       Conflicts => PolyORB.Initialization.String_Lists.Empty,
       Depends   => PolyORB.Initialization.String_Lists.Empty,
       Provides  => PolyORB.Initialization.String_Lists.Empty,
       Implicit  => False,
       Init      => Initialize'Access,
       Shutdown  => null));
end PolyORB.Binding_Data.GIOP.IIOP.Print;
