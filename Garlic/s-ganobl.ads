------------------------------------------------------------------------------
--                                                                          --
--                            GLADE COMPONENTS                              --
--                                                                          --
--          S Y S T E M . G A R L I C . N O N _ B L O C K I N G             --
--                                                                          --
--                                S p e c                                   --
--                                                                          --
--                           $Revision$                              --
--                                                                          --
--           Copyright (C) 1996 Free Software Foundation, Inc.              --
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
--            (email:distribution@act-europe.gnat.com).                     --
--                                                                          --
------------------------------------------------------------------------------

with Interfaces.C.Strings;
with System.Garlic.Thin;

package System.Garlic.Non_Blocking is

   --  This package provides replacement routine for some System.Garlic.Thin
   --  subprograms which are potentially blocking. This allows some units to
   --  work even on SunOS platforms where the pthreads library doesn't
   --  provide thread-blocking I/Os.

   package C renames Interfaces.C;
   package Strings renames C.Strings;

   function C_Accept
     (S       : C.int;
      Addr    : Thin.Sockaddr_Access;
      Addrlen : access C.int)
     return C.int;
   --  Thread blocking accept.

   function C_Connect
     (S       : C.int;
      Name    : Thin.Sockaddr_Access;
      Namelen : C.int)
     return C.int;
   --  Thread blocking connect.

   function C_Read
     (Filedes : C.int;
      Buf     : Strings.chars_ptr;
      Nbyte   : C.int)
     return C.int;
   --  Thread blocking read.

   function C_Write
     (Fildes : C.int;
      Buf    : Strings.chars_ptr;
      Nbyte  : C.int)
     return C.int;
   --  Thread blocking write.

end System.Garlic.Non_Blocking;


