------------------------------------------------------------------------------
--                                                                          --
--                          ADABROKER COMPONENTS                            --
--                                                                          --
--                          C O R B A . V A L U E                           --
--                                                                          --
--                                 B o d y                                  --
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

with Broca.Value.Value_Skel;
with Broca.Exceptions;

package body CORBA.Value is

   ------------
   --  Is_A  --
   ------------
   --  This code is copied from what is generated by idlac
   --  for any usual function call. This method is inherited
   --  by all valuetypes. Unlike Interfaces, we do not have to
   --  override this method in every valuetype. The only reason
   --  why we override this method for interfaces is to avoid
   --  the remote call. There cannot be any remote call with valuetypes
   --  so let's keep it simple like that.

   function Is_A
     (Self : in Base;
      Logical_Type_Id : Standard.String)
      return CORBA.Boolean
   is
      Is_A_Operation : Broca.Value.Value_Skel.Is_A_Type;
      Precise_Object : constant CORBA.Impl.Object_Ptr
        := CORBA.Impl.Object_Ptr (Object_Of (Self));
   begin
      --  Sanity check
      if Is_Nil (Self) then
         Broca.Exceptions.Raise_Inv_Objref;
      end if;

      --  Find the operation
      Is_A_Operation :=
        Broca.Value.Value_Skel.Is_A_Store.Get_Operation
        (Precise_Object.all'Tag);

      --  Call it operation
      return
        Is_A_Operation (Logical_Type_Id);

   end Is_A;

end CORBA.Value;
