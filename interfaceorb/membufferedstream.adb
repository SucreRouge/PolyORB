-----------------------------------------------------------------------
-----------------------------------------------------------------------
----                                                               ----
----                         AdaBroker                             ----
----                                                               ----
----                 package membufferedstream                     ----
----                                                               ----
----                                                               ----
----   Copyright (C) 1999 ENST                                     ----
----                                                               ----
----   This file is part of the AdaBroker library                  ----
----                                                               ----
----   The AdaBroker library is free software; you can             ----
----   redistribute it and/or modify it under the terms of the     ----
----   GNU Library General Public License as published by the      ----
----   Free Software Foundation; either version 2 of the License,  ----
----   or (at your option) any later version.                      ----
----                                                               ----
----   This library is distributed in the hope that it will be     ----
----   useful, but WITHOUT ANY WARRANTY; without even the implied  ----
----   warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR     ----
----   PURPOSE.  See the GNU Library General Public License for    ----
----   more details.                                               ----
----                                                               ----
----   You should have received a copy of the GNU Library General  ----
----   Public License along with this library; if not, write to    ----
----   the Free Software Foundation, Inc., 59 Temple Place -       ----
----   Suite 330, Boston, MA 02111-1307, USA                       ----
----                                                               ----
----                                                               ----
----                                                               ----
----   Description                                                 ----
----   -----------                                                 ----
----                                                               ----
----     This package is wrapped around a C++ class whose name     ----
----   is Ada_memBufferedStream. (see Ada_memBufferedStream.hh)    ----
----     It provides two types of methods : the C functions        ----
----   of the Ada_memBufferedStream class and their equivalent     ----
----   in Ada. (he first ones have a C_ prefix.)                   ----
----     In addition, there is a raise_ada_exception function      ----
----   that allows C functions to raise the ada No_Initialisation  ----
----   exception.                                                  ----
----     At last, there is only one Init procedure in place of     ----
----   two in Ada_memBufferedStream since the second one is        ----
----   useless for AdaBroker.                                      ----
----                                                               ----
----                                                               ----
----   authors : Sebastien Ponce, Fabien Azavant                   ----
----   date    : 02/28/99                                          ----
----                                                               ----
-----------------------------------------------------------------------
-----------------------------------------------------------------------


with Ada.Unchecked_Conversion ;
with Ada.Exceptions ;
with Ada.Strings.Unbounded ;
use type Ada.Strings.Unbounded.Unbounded_String ;
with Ada.Strings ;
with Ada.Characters.Latin_1 ;

with Corba ;
use type Corba.String ;
use type Corba.Unsigned_Long ;
with Omni ;

package body MemBufferedStream is

   -- Ada_To_C_Unsigned_Long
   -------------------------
   function Ada_To_C_Unsigned_Long is
     new Ada.Unchecked_Conversion (Corba.Unsigned_Long,
                                   Interfaces.C.Unsigned_Long) ;
   -- needed to change ada type Corba.Unsigned_Long
   -- into C type Interfaces.C.Unsigned_Long


   -- C_Init
   ---------
   procedure C_Init (Self : in Object'Class ;
                     Bufsize : in Interfaces.C.Unsigned_Long) ;
   pragma Import (C,C_Init,"__17MemBufferedStreamUi") ;
   -- wrapper around Ada_MemBufferedStream function Init
   -- (see Ada_MemBufferedStream.hh)
   -- name was changed to avoid conflict
   -- called by the Ada equivalent : Init


   -- Init
   -------
   procedure Init (Self : in Object'Class ;
                   Bufsize : in Corba.Unsigned_Long) is
      C_Bufsize : Interfaces.C.Unsigned_Long ;
   begin
      -- transforms the arguments into a C type ...
      C_Bufsize := Ada_To_C_Unsigned_Long (Bufsize) ;
      -- ... and calls the C procedure
      C_Init (Self, C_Bufsize) ;
   end ;


   -- Ada_To_C_Char
   ----------------
   function Ada_To_C_Char is
     new Ada.Unchecked_Conversion (Corba.Char,
                                   Interfaces.C.Char) ;
   -- needed to change ada type Corba.Char
   -- into C type Interfaces.C.Char


   -- C_Marshall_1
   ---------------
   procedure C_Marshall_1 (A : in Interfaces.C.Char ;
                           S : in out System.Address) ;
   pragma Import (C,C_Marshall_1,"marshall__21Ada_memBufferedStreamUcR17MemBufferedStream") ;
   -- wrapper around Ada_MemBufferedStream function marshall
   -- (see Ada_MemBufferedStream.hh)
   -- name was changed to avoid conflict
   -- called by the Ada equivalent : Marshall


   -- Marshall
   -----------
   procedure Marshall (A : in Corba.Char ;
                       S : in out Object'Class) is
      C_A : Interfaces.C.Char ;
      C_S : System.Address ;
   begin
      -- transforms the arguments in a C type ...
      C_A := Ada_To_C_Char (A) ;
      C_S := S'Address ;
      -- ... and calls the C procedure
      C_Marshall_1 (C_A,C_S) ;
   end;


   -- C_UnMarshall_1
   -----------------
   procedure C_UnMarshall_1 (A : out System.Address ;
                             S : in out System.Address) ;
   pragma Import (C,C_UnMarshall_1,"unmarshall__21Ada_memBufferedStreamRUcR17MemBufferedStream") ;
   -- wrapper around Ada_MemBufferedStream function marshall
   -- (see Ada_MemBufferedStream.hh)
   -- name was changed to avoid conflict
   -- called by the Ada equivalent : UnMarshall


   -- UnMarshall
   -------------
   procedure UnMarshall (A : out Corba.Char ;
                         S : in out Object'Class) is
      C_A : System.Address ;
      C_S : System.Address ;
   begin
      -- transforms the arguments in a C type ...
      C_A := A'Address ;
      C_S := S'Address ;
      -- ... and calls the C procedure
      C_UnMarshall_1 (C_A,C_S) ;
   end;


   -- Align_Size
   -------------
   function Align_Size (A : in Corba.Char ;
                        Initial_Offset : in Corba.Unsigned_Long)
                        return Corba.Unsigned_Long is
   begin
      -- no alignment needed here
      return Initial_Offset + 1 ;
   end ;


   -- C_Marshall_2
   ---------------
   procedure C_Marshall_2 (A : in Sys_Dep.C_Boolean ;
                           S : in out System.Address) ;
   pragma Import (C,C_Marshall_2,"marshall__21Ada_memBufferedStreambR17MemBufferedStream") ;
   -- wrapper around Ada_MemBufferedStream function marshall
   -- (see Ada_MemBufferedStream.hh)
   -- name was changed to avoid conflict
   -- called by the Ada equivalent : Marshall


   -- Marshall
   -----------
   procedure Marshall (A : in Corba.Boolean ;
                       S : in out Object'Class) is
      C_A : Sys_Dep.C_Boolean ;
      C_S : System.Address ;
   begin
      -- transforms the arguments in a C type ...
      C_A := Sys_Dep.Boolean_Ada_To_C (A) ;
      C_S := S'Address ;
      -- ... and calls the C procedure
      C_Marshall_2 (C_A,C_S) ;
   end;


   -- C_UnMarshall_2
   -----------------
   procedure C_UnMarshall_2 (A : out System.Address ;
                             S : in out System.Address) ;
   pragma Import (C,C_UnMarshall_2,"unmarshall__21Ada_memBufferedStreamRbR17MemBufferedStream") ;
   -- wrapper around Ada_MemBufferedStream function marshall
   -- (see Ada_MemBufferedStream.hh)
   -- name was changed to avoid conflict
   -- called by the Ada equivalent : UnMarshall


   -- UnMarshall
   -------------
   procedure UnMarshall (A : out Corba.Boolean ;
                         S : in out Object'Class) is
      C_A : System.Address ;
      C_S : System.Address ;
   begin
      -- transforms the arguments in a C type ...
      C_A := A'Address ;
      C_S := S'Address ;
      -- ... and calls the C procedure
      C_UnMarshall_2 (C_A,C_S) ;
   end;


   -- Align_Size
   -------------
   function Align_Size (A : in Corba.Boolean ;
                        Initial_Offset : in Corba.Unsigned_Long)
                        return Corba.Unsigned_Long is
   begin
      -- no alignment needed here
      return Initial_Offset + 1 ;
      -- Boolean is marshalled as an unsigned_char
   end ;


   -- Ada_To_C_Short
   -----------------
   function Ada_To_C_Short is
     new Ada.Unchecked_Conversion (Corba.Short,
                                   Interfaces.C.Short) ;
   -- needed to change ada type Corba.Short
   -- into C type Interfaces.C.Short


   -- C_Marshall_3
   ---------------
   procedure C_Marshall_3 (A : in Interfaces.C.Short ;
                           S : in out System.Address) ;
   pragma Import (C,C_Marshall_3,"marshall__21Ada_memBufferedStreamsR17MemBufferedStream") ;
   -- wrapper around Ada_MemBufferedStream function marshall
   -- (see Ada_MemBufferedStream.hh)
   -- name was changed to avoid conflict
   -- called by the Ada equivalent : Marshall


   -- Marshall
   -----------
   procedure Marshall (A : in Corba.Short ;
                       S : in out Object'Class) is
      C_A : Interfaces.C.Short ;
      C_S : System.Address ;
   begin
      -- transforms the arguments in a C type ...
      C_A := Ada_To_C_Short (A) ;
      C_S := S'Address ;
      -- ... and calls the C procedure
      C_Marshall_3 (C_A,C_S) ;
   end;


   -- C_UnMarshall_3
   -----------------
   procedure C_UnMarshall_3 (A : out System.Address ;
                             S : in out System.Address) ;
   pragma Import (C,C_UnMarshall_3,"unmarshall__21Ada_memBufferedStreamRsR17MemBufferedStream") ;
   -- wrapper around Ada_MemBufferedStream function marshall
   -- (see Ada_MemBufferedStream.hh)
   -- name was changed to avoid conflict
   -- called by the Ada equivalent : UnMarshall


   -- UnMarshall
   -------------
   procedure UnMarshall (A : out Corba.Short ;
                         S : in out Object'Class) is
      C_A : System.Address ;
      C_S : System.Address ;
   begin
      -- transforms the arguments in a C type ...
      C_A := A'Address ;
      C_S := S'Address ;
      -- ... and calls the C procedure
      C_UnMarshall_3 (C_A,C_S) ;
   end;


   -- Align_Size
   -------------
   function Align_Size (A : in Corba.Short ;
                        Initial_Offset : in Corba.Unsigned_Long)
                        return Corba.Unsigned_Long is
      Tmp : Corba.Unsigned_Long ;
   begin
      Tmp := Omni.Align_To (Initial_Offset,Omni.ALIGN_2) ;
      return Tmp + 2 ;
   end ;


   -- Ada_To_C_Unsigned_Short
   --------------------------
   function Ada_To_C_Unsigned_Short is
     new Ada.Unchecked_Conversion (Corba.Unsigned_Short,
                                   Interfaces.C.Unsigned_Short) ;
   -- needed to change ada type Corba.Unsigned_Short
   -- into C type Interfaces.C.Unsigned_Short


   -- C_Marshall_4
   ---------------
   procedure C_Marshall_4 (A : in Interfaces.C.Unsigned_Short ;
                           S : in out System.Address) ;
   pragma Import (C,C_Marshall_4,"marshall__21Ada_memBufferedStreamUsR17MemBufferedStream") ;
   -- wrapper around Ada_MemBufferedStream function marshall
   -- (see Ada_MemBufferedStream.hh)
   -- name was changed to avoid conflict
   -- called by the Ada equivalent : Marshall


   -- Marshall
   -----------
   procedure Marshall (A : in Corba.Unsigned_Short ;
                       S : in out Object'Class) is
      C_A : Interfaces.C.Unsigned_Short ;
      C_S : System.Address ;
   begin
      -- transforms the arguments in a C type ...
      C_A := Ada_To_C_Unsigned_Short (A) ;
      C_S := S'Address ;
      -- ... and calls the C procedure
      C_Marshall_4 (C_A,C_S) ;
   end;


   -- C_UnMarshall_4
   -----------------
   procedure C_UnMarshall_4 (A : out System.Address ;
                             S : in out System.Address) ;
   pragma Import (C,C_UnMarshall_4,"unmarshall__21Ada_memBufferedStreamRUsR17MemBufferedStream") ;
   -- wrapper around Ada_MemBufferedStream function marshall
   -- (see Ada_MemBufferedStream.hh)
   -- name was changed to avoid conflict
   -- called by the Ada equivalent : UnMarshall


   -- UnMarshall
   -------------
   procedure UnMarshall (A : out Corba.Unsigned_Short ;
                         S : in out Object'Class) is
      C_A : System.Address ;
      C_S : System.Address ;
   begin
      -- transforms the arguments in a C type ...
      C_A := A'Address ;
      C_S := S'Address ;
      -- ... and calls the C procedure
      C_UnMarshall_4 (C_A,C_S) ;
   end;


   -- Align_Size
   -------------
   function Align_Size (A : in Corba.Unsigned_Short ;
                        Initial_Offset : in Corba.Unsigned_Long)
                        return Corba.Unsigned_Long is
      Tmp : Corba.Unsigned_Long ;
   begin
      Tmp := Omni.Align_To (Initial_Offset,Omni.ALIGN_2) ;
      return Tmp + 2 ;
   end ;


   -- Ada_To_C_Long
   -----------------
   function Ada_To_C_Long is
     new Ada.Unchecked_Conversion (Corba.Long,
                                   Interfaces.C.Long) ;
   -- needed to change ada type Corba.Long
   -- into C type Interfaces.C.Long


   -- C_Marshall_5
   ---------------
   procedure C_Marshall_5 (A : in Interfaces.C.Long ;
                           S : in out System.Address) ;
   pragma Import (C,C_Marshall_5,"marshall__21Ada_memBufferedStreamlR17MemBufferedStream") ;
   -- wrapper around Ada_MemBufferedStream function marshall
   -- (see Ada_MemBufferedStream.hh)
   -- name was changed to avoid conflict
   -- called by the Ada equivalent : Marshall


   -- Marshall
   -----------
   procedure Marshall (A : in Corba.Long ;
                       S : in out Object'Class) is
      C_A : Interfaces.C.Long ;
      C_S : System.Address ;
   begin
      -- transforms the arguments in a C type ...
      C_A := Ada_To_C_Long (A) ;
      C_S := S'Address ;
      -- ... and calls the C procedure
      C_Marshall_5 (C_A,C_S) ;
   end;


   -- C_UnMarshall_5
   -----------------
   procedure C_UnMarshall_5 (A : out System.Address ;
                             S : in out System.Address) ;
   pragma Import (C,C_UnMarshall_5,"unmarshall__21Ada_memBufferedStreamRlR17MemBufferedStream") ;
   -- wrapper around Ada_MemBufferedStream function marshall
   -- (see Ada_MemBufferedStream.hh)
   -- name was changed to avoid conflict
   -- called by the Ada equivalent : UnMarshall


   -- UnMarshall
   -------------
   procedure UnMarshall (A : out Corba.Long ;
                         S : in out Object'Class) is
      C_A : System.Address ;
      C_S : System.Address ;
   begin
      -- transforms the arguments in a C type ...
      C_A := A'Address ;
      C_S := S'Address ;
      -- ... and calls the C procedure
      C_UnMarshall_5 (C_A,C_S) ;
   end;


   -- Align_Size
   -------------
   function Align_Size (A : in Corba.Long ;
                        Initial_Offset : in Corba.Unsigned_Long)
                        return Corba.Unsigned_Long is
      Tmp : Corba.Unsigned_Long ;
   begin
      Tmp := Omni.Align_To (Initial_Offset,Omni.ALIGN_4) ;
      return Tmp + 4 ;
   end ;


   -- C_Marshall_6
   ---------------
   procedure C_Marshall_6 (A : in Interfaces.C.Unsigned_Long ;
                           S : in out System.Address) ;
   pragma Import (C,C_Marshall_6,"marshall__21Ada_memBufferedStreamUlR17MemBufferedStream") ;
   -- wrapper around Ada_MemBufferedStream function marshall
   -- (see Ada_MemBufferedStream.hh)
   -- name was changed to avoid conflict
   -- called by the Ada equivalent : Marshall


   -- Marshall
   -----------
   procedure Marshall (A : in Corba.Unsigned_Long ;
                       S : in out Object'Class) is
      C_A : Interfaces.C.Unsigned_Long ;
      C_S : System.Address ;
   begin
      -- transforms the arguments in a C type ...
      C_A := Ada_To_C_Unsigned_Long (A) ;
      C_S := S'Address ;
      -- ... and calls the C procedure
      C_Marshall_6 (C_A,C_S) ;
   end;


   -- C_UnMarshall_6
   -----------------
   procedure C_UnMarshall_6 (A : out System.Address ;
                             S : in out System.Address) ;
   pragma Import (C,C_UnMarshall_6,"unmarshall__21Ada_memBufferedStreamRUlR17MemBufferedStream") ;
   -- wrapper around Ada_MemBufferedStream function marshall
   -- (see Ada_MemBufferedStream.hh)
   -- name was changed to avoid conflict
   -- called by the Ada equivalent : UnMarshall


   -- UnMarshall
   -------------
   procedure UnMarshall (A : out Corba.Unsigned_Long ;
                         S : in out Object'Class) is
      C_A : System.Address ;
      C_S : System.Address ;
   begin
      -- transforms the arguments in a C type ...
      C_A := A'Address ;
      C_S := S'Address ;
      -- ... and calls the C procedure
      C_UnMarshall_6 (C_A,C_S) ;
   end;


   -- Align_Size
   -------------
   function Align_Size (A : in Corba.Unsigned_Long ;
                        Initial_Offset : in Corba.Unsigned_Long)
                        return Corba.Unsigned_Long is
      Tmp : Corba.Unsigned_Long ;
   begin
      Tmp := Omni.Align_To (Initial_Offset,Omni.ALIGN_4) ;
      return Tmp + 4 ;
   end ;


   -- Ada_To_C_Float
   -----------------
   function Ada_To_C_Float is
     new Ada.Unchecked_Conversion (Corba.Float,
                                   Interfaces.C.C_Float) ;
   -- needed to change ada type Corba.Float
   -- into C type Interfaces.C.C_Float


   -- C_Marshall_7
   ---------------
   procedure C_Marshall_7 (A : in Interfaces.C.C_Float ;
                           S : in out System.Address) ;
   pragma Import (C,C_Marshall_7,"marshall__21Ada_memBufferedStreamfR17MemBufferedStream") ;
   -- wrapper around Ada_MemBufferedStream function marshall
   -- (see Ada_MemBufferedStream.hh)
   -- name was changed to avoid conflict


   -- Marshall
   -----------
   procedure Marshall (A : in Corba.Float ;
                       S : in out Object'Class) is
      C_A : Interfaces.C.C_Float ;
      C_S : System.Address ;
   begin
      -- transforms the arguments in a C type ...
      C_A := Ada_To_C_Float (A) ;
      C_S := S'Address ;
      -- ... and calls the C procedure
      C_Marshall_7 (C_A,C_S) ;
   end;


   -- C_UnMarshall_7
   -----------------
   procedure C_UnMarshall_7 (A : out System.Address ;
                             S : in out System.Address) ;
   pragma Import (C,C_UnMarshall_7,"unmarshall__21Ada_memBufferedStreamRfR17MemBufferedStream") ;
   -- wrapper around Ada_MemBufferedStream function marshall
   -- (see Ada_MemBufferedStream.hh)
   -- name was changed to avoid conflict


   -- UnMarshall
   -------------
   procedure UnMarshall (A : out Corba.Float ;
                         S : in out Object'Class) is
      C_A : System.Address ;
      C_S : System.Address ;
   begin
      -- transforms the arguments in a C type ...
      C_A := A'Address ;
      C_S := S'Address ;
      -- ... and calls the C procedure
      C_UnMarshall_7 (C_A,C_S) ;
   end;


   -- Align_Size
   -------------
   function Align_Size (A : in Corba.Float ;
                        Initial_Offset : in Corba.Unsigned_Long)
                        return Corba.Unsigned_Long is
      Tmp : Corba.Unsigned_Long ;
   begin
      Tmp := Omni.Align_To (Initial_Offset,Omni.ALIGN_4) ;
      return Tmp + 4 ;
   end ;


   -- Ada_To_C_Double
   ------------------
   function Ada_To_C_Double is
     new Ada.Unchecked_Conversion (Corba.Double,
                                   Interfaces.C.Double) ;
   -- needed to change ada type Corba.Double
   -- into C type Interfaces.C.Double


   -- C_Marshall_8
   ---------------
   procedure C_Marshall_8 (A : in Interfaces.C.Double ;
                           S : in out System.Address) ;
   pragma Import (C,C_Marshall_8,"marshall__21Ada_memBufferedStreamdR17MemBufferedStream") ;
   -- wrapper around Ada_MemBufferedStream function marshall
   -- (see Ada_MemBufferedStream.hh)
   -- name was changed to avoid conflict
   -- called by the Ada equivalent : Marshall


   -- Marshall
   -----------
   procedure Marshall (A : in Corba.Double ;
                       S : in out Object'Class) is
      C_A : Interfaces.C.Double ;
      C_S : System.Address ;
   begin
      -- transforms the arguments in a C type ...
      C_A := Ada_To_C_Double (A) ;
      C_S := S'Address ;
      -- ... and calls the C procedure
      C_Marshall_8 (C_A,C_S) ;
   end;


   --C_UnMarshall_8
   ----------------
   procedure C_UnMarshall_8 (A : out System.Address ;
                             S : in out System.Address) ;
   pragma Import (C,C_UnMarshall_8,"unmarshall__21Ada_memBufferedStreamRdR17MemBufferedStream") ;
   -- wrapper around Ada_MemBufferedStream function marshall
   -- (see Ada_MemBufferedStream.hh)
   -- name was changed to avoid conflict


   -- UnMarshall
   -------------
   procedure UnMarshall (A : out Corba.Double ;
                         S : in out Object'Class) is
      C_A : System.Address ;
      C_S : System.Address ;
   begin
      -- transforms the arguments in a C type ...
      C_A := A'Address ;
      C_S := S'Address ;
      -- ... and calls the C procedure
      C_UnMarshall_8 (C_A,C_S) ;
   end;


   -- Align_Size
   -------------
   function Align_Size (A : in Corba.Double ;
                        Initial_Offset : in Corba.Unsigned_Long)
                        return Corba.Unsigned_Long is
      Tmp : Corba.Unsigned_Long ;
   begin
      Tmp := Omni.Align_To (Initial_Offset,Omni.ALIGN_8) ;
      return Tmp + 8 ;
   end ;


   -- Marshall
   -----------
   procedure Marshall (A : in Corba.String ;
                       S : in out Object'Class) is
      Size : Corba.Unsigned_Long ;
      C : Standard.Character ;
   begin
      -- first marshall the size of the string + 1
      -- 1 is the size of the null character we must marshall
      -- at the end of the string (C style)
      Size := Corba.Length (A) + Corba.Unsigned_Long (1) ;
      Marshall (Size , S) ;
      -- Then marshall the string itself and a null character at the end
      for I in 1..Integer(Size) loop
         C := Ada.Strings.Unbounded.Element (Ada.Strings.Unbounded.Unbounded_String (A),I) ;
         Marshall (C,S) ;
      end loop ;
      Marshall (Corba.Char (Ada.Characters.Latin_1.nul),S) ;
   end ;


   -- UnMarshall
   -------------
   procedure UnMarshall (A : out Corba.String ;
                         S : in out Object'Class) is
      Size : Corba.Unsigned_Long ;
      C : Standard.Character ;
   begin
      -- first unmarshalls the size of the string
      UnMarshall (Size,S) ;
      case Size is
         when 0 =>
            -- the size is never 0 so raise exception if it is the case
            Ada.Exceptions.Raise_Exception(Corba.Adabroker_Fatal_Error'Identity,
                                           "Size of the string was 0 in netbufferedstream.UnMarshall.") ;
         when 1 =>
            -- if the size is 1 then the String is empty
            A := Corba.String (Ada.Strings.Unbounded.To_Unbounded_String ("")) ;
         when others =>
            -- else we can unmarshall the string
            declare
               Tmp : String (1..Integer(Size)-1) ;
            begin
               for I in 1..Integer(Size)-1 loop
                  UnMarshall (Tmp(I),S);
               end loop ;
               A := Corba.String (Ada.Strings.Unbounded.To_Unbounded_String (Tmp)) ;
            end ;
      end case ;
      -- unmarshall the null character at the end of the string (C style)
      -- and verify it is null
      UnMarshall (C,S) ;
      if C /= Ada.Characters.Latin_1.Nul then
         Ada.Exceptions.Raise_Exception(Corba.Adabroker_Fatal_Error'Identity,
                                        "Size not ended by null character in netbufferedstream.UnMarshall.") ;
      end if ;
   end ;


   -- Align_Size
   -------------
   function Align_Size (A : in Corba.String ;
                        Initial_Offset : in Corba.Unsigned_Long)
                        return Corba.Unsigned_Long is
   begin
      -- no alignment needed here
      return Initial_Offset + Corba.Length (A) + 1 ;
      -- + 1 is for the null character (the strings ar marshalled in C style)
   end ;


   -- Marshall
   -----------
   procedure Marshall (A : in Corba.Completion_Status ;
                       S : in out Object'Class) is
   begin
      -- maps the possible values on the firste shorts
      -- and marshall the right one
      case A is
         when Corba.Completed_Yes =>
            Marshall (Corba.Unsigned_Short (1),S) ;
         when Corba.Completed_No =>
            Marshall (Corba.Unsigned_Short (2),S) ;
         when Corba.Completed_Maybe =>
            Marshall (Corba.Unsigned_Short (3),S) ;
      end case ;
   end;


   -- UnMarshall
   -------------
   procedure UnMarshall (A : out Corba.Completion_Status ;
                         S : in out Object'Class) is
      Tmp : Corba.Unsigned_Short ;
   begin
      -- unmarshalls an unsigned short
      UnMarshall (Tmp,S) ;
      -- and returns the corresponding Completion_Status
      case Tmp is
         when 1 =>
            A := Corba.Completed_Yes ;
         when 2 =>
            A := Corba.Completed_No ;
         when 3 =>
            A := Corba.Completed_Maybe ;
         when others =>
            Ada.Exceptions.Raise_Exception (Corba.AdaBroker_Fatal_Error'Identity,
                                            "Expected Completion_Status in netbufferedstream.UnMarshall" & Corba.CRLF &
                                            "Short out of range" & Corba.CRLF &
                                            "(see netbufferedstream L660)");
      end case ;
   end;


   -- Align_Size
   -------------
   function Align_Size (A : in Corba.Completion_Status ;
                        Initial_Offset : in Corba.Unsigned_Long)
                        return Corba.Unsigned_Long is
   begin
      -- no alignment needed here
      return Initial_Offset + 1 ;
      -- a Completion_Status is marshalled as an unsigned_short
   end ;


   -- Marshall
   -----------
   procedure Marshall (A : in Corba.Ex_Body'Class ;
                       S : in out Object'Class) is
   begin
      -- just marshall each field
      Marshall (A.Minor,S) ;
      Marshall (A.Completed,S) ;
   end;


   -- UnMarshall
   -------------
   procedure UnMarshall (A : out Corba.Ex_Body'Class ;
                         S : in out Object'Class) is
      Minor : Corba.Unsigned_Long ;
      Completed : Corba.Completion_Status ;
   begin
      -- Unmarshalls the two fields
      UnMarshall (Completed,S) ;
      UnMarshall (Minor,S) ;
      -- and return the object
      A.Minor := Minor ;
      A.Completed := Completed ;
   end;

   -- Align_Size
   -------------
   function Align_Size (A : in Corba.Ex_Body ;
                        Initial_Offset : in Corba.Unsigned_Long)
                        return Corba.Unsigned_Long is
      Tmp : Corba.Unsigned_Long ;
   begin
      Tmp := Omni.Align_To (Initial_Offset,Omni.ALIGN_4) ;
      return Initial_Offset + 5 ;
      -- an Ex_body has two fields : an unsigned_long -> 4 bytes
      --                             and a Completion_Status -> 1 bytes
   end ;

end MemBufferedStream ;


