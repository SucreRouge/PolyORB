------------------------------------------------------------------------------
--                                                                          --
--                          ADABROKER COMPONENTS                            --
--                                                                          --
--          B R O C A . V A L U E . O P E R A T I O N _ S T O R E           --
--                                                                          --
--                                 S p e c                                  --
--                                                                          --
--          Copyright (C) 1999-2000 ENST Paris University, France.          --
--                                                                          --
-- AdaBroker is free software; you  can  redistribute  it and/or modify it  --
-- under terms of the  GNU General Public License as published by the  Free --
-- Software Foundation;  either version 2,  or (at your option)  any  later --
-- version. AdaBroker  is distributed  in the hope that it will be  useful, --
-- but WITHOUT ANY WARRANTY;  without even the implied warranty of MERCHAN- --
-- TABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public --
-- License  for more details.  You should have received  a copy of the GNU  --
-- General Public License distributed with AdaBroker; see file COPYING. If  --
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
--             AdaBroker is maintained by ENST Paris University.            --
--                     (email: broker@inf.enst.fr)                          --
--                                                                          --
------------------------------------------------------------------------------

--  This package implements a generic linked list to store the
--  operations associated with a valuetype implementation object
--  type.

with Ada.Tags;

generic

   type Operation_Type is private;
   --  Typically an access to subprogram type

package Broca.Value.Operation_Store is

   procedure Register_Operation
     (T : in Ada.Tags.Tag;
      Op : in Operation_Type);
   --  Register an operation for a tagged type
   --  derived from CORBA.Value.Impl_Base

   function Get_Operation
     (T : in Ada.Tags.Tag)
     return Operation_Type;
   --  Retrieves the stored operation for this type.
   --  Raises CORBA.Internal if not found

end Broca.Value.Operation_Store;
